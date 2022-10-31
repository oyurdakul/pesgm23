# -*- coding: utf-8 -*-
"""
Created on Wed Oct 26 18:19:09 2022

@author: farha
"""

# standard libraries
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Tuple


# NEM data libraries
# NEMOSIS for actual demand data
# NEMSEER for forecast demand data
import nemosis
from nemseer import compile_data, download_raw_data, generate_runtimes

# data wrangling libraries
import pandas as pd
import xarray as xr
import numpy as np
import scipy as scipy
from scipy import stats

# interactive plotting
from plotly.subplots import make_subplots
import plotly.express as px
import plotly.graph_objects as go
import plotly.io as pio

# static plotting
import matplotlib.pyplot as plt

# silence NEMSEER and NEMOSIS logging
logging.getLogger("nemosis").setLevel(logging.WARNING)
logging.getLogger("nemseer").setLevel(logging.ERROR)

analysis_start = "2019/01/01 00:00:00"
analysis_end = "2020/01/01 00:00:00"

nemosis_cache = Path("nemosis_cache/")
if not nemosis_cache.exists():
    nemosis_cache.mkdir()
    
nemosis.cache_compiler(
    analysis_start, analysis_end, "TRADINGPRICE", nemosis_cache, fformat="parquet"
)


download_raw_data(
    "PREDISPATCH",
    "PRICE",
    "nemseer_cache/",
    forecasted_start=analysis_start,
    forecasted_end=analysis_end,
)


def calculate_price_error(analysis_start: str, analysis_end: str) -> pd.DataFrame:
    """
    Calculates price error in PREDISPATCH and P5MIN forecasts for periods between
    analysis_start and analysis_end.

    Args:
        analysis_start: Start datetime, YYYY/mm/dd HH:MM:SS
        analysis_end: End datetime, YYYY/mm/dd HH:MM:SS
    Returns:
        DataFrame with computed price error mapped to the ahead time of the
        forecast and the forecasted time.
    """

    def get_actual_price_data() -> pd.DataFrame:
        """
        Gets actual price data
        """
        # get actual demand data for forecasted_time
        # nemosis start time must precede end of interval of interest by 5 minutes
        nemosis_window = (
            (
                datetime.strptime(analysis_start, "%Y/%m/%d %H:%M:%S")
                - timedelta(minutes=30)
            ).strftime("%Y/%m/%d %H:%M:%S"),
            analysis_end,
        )
        nemosis_price = nemosis.dynamic_data_compiler(
            nemosis_window[0],
            nemosis_window[1],
            "TRADINGPRICE",
            nemosis_cache,
            filter_cols=["PRICE_STATUS"],
            filter_values=(["FIRM"],),
        )
        actual_price = nemosis_price[["SETTLEMENTDATE", "REGIONID", "RRP"]]
        actual_price = actual_price.rename(
            columns={"SETTLEMENTDATE": "forecasted_time"}
        )
        
        return actual_price

    def get_forecast_price_data(ftype: str) -> pd.DataFrame:
        """
        Get price forecast data for the analysis period given a particular forecast type

        Args:
            ftype: 'P5MIN' or 'PREDISPATCH'
        Returns:
            DataFrame with price forecast data
        """
        # ftype mappings
        table = {"PREDISPATCH": "PRICE", "P5MIN": "REGIONSOLUTION"}
        run_col = {"PREDISPATCH": "PREDISPATCH_RUN_DATETIME", "P5MIN": "RUN_DATETIME"}
        forecasted_col = {"PREDISPATCH": "DATETIME", "P5MIN": "INTERVAL_DATETIME"}
        # get run times
        forecasts_run_start, forecasts_run_end = generate_runtimes(
            analysis_start, analysis_end, ftype
        )
        df = compile_data(
            forecasts_run_start,
            forecasts_run_end,
            analysis_start,
            analysis_end,
            ftype,
            table[ftype],
            "nemseer_cache/",
        )[table[ftype]]
        # remove intervention periods
        df = df.query("INTERVENTION == 0")
        # rename run and forecasted time cols
        df = df.rename(
            columns={
                run_col[ftype]: "run_time",
                forecasted_col[ftype]: "forecasted_time",
                
            }
        )
        df = df.rename(columns={"RRP": "FORECASTED_RRP"})
        print(df.keys())
        # ensure values are sorted by forecasted and run times for nth groupby operation
        return df[["run_time", "forecasted_time", "REGIONID", "FORECASTED_RRP"]].sort_values(
            ["forecasted_time", "run_time"]
        )

    def combine_pd_p5_forecasts(
        p5_df: pd.DataFrame, pd_df: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Combines P5 and PD forecasts, including removing PD overlap with P5
        """
        # remove PD overlap with P5MIN
        pd_nooverlap = pd_df.groupby(
            ["forecasted_time", "REGIONID"], as_index=False
        ).nth(slice(None, -2))
        # concatenate and rename RRP to reflect that these are forecasted values
        forecast_prices = pd.concat([pd_nooverlap, p5_df], axis=0).sort_values(
            ["forecasted_time", "actual_run_time"]
        )
        #print(forecast_prices)
        forecast_prices = forecast_prices.rename(columns={"RRP": "FORECASTED_RRP"})
        return forecast_prices

    def process_price_error(
        forecast_prices: pd.DataFrame, actual_price: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Merges actual and forecast prices and calculates ahead time and price error
        """
        # left merge to ensure each forecasted price is mapped to its corresponding actual price
        all_prices = pd.merge(
            forecast_prices,
            actual_price,
            how="left",
            on=["forecasted_time", "REGIONID"],
        )
        
        all_prices["ahead_time"] = (
            all_prices["forecasted_time"] - all_prices["actual_run_time"]
        )
        
        all_prices["error"] = all_prices["RRP"] - all_prices["FORECASTED_RRP"]
        price_error = all_prices.drop(
            columns=["RRP", "FORECASTED_RRP", "actual_run_time"]
        )
        return price_error

    
    pd_df = get_forecast_price_data("PREDISPATCH")
    # calulate actual run time for each forecast type
    pd_df["actual_run_time"] = pd_df["run_time"] - pd.Timedelta(minutes=30)
    pd_df = pd_df.drop(columns="run_time")
    # get forecast prices
    forecast_prices = pd_df #combine_pd_p5_forecasts(p5_df, pd_df)

    # actual prices
    actual_price = get_actual_price_data()

    price_error = process_price_error(forecast_prices, actual_price)
    return price_error

price_error = calculate_price_error(analysis_start, analysis_end)

region = "SA1"
aheads = price_error.ahead_time.unique()#sort()#dict(minutes=30), dict(hours=1), dict(hours=5), dict(days=1)]
region_price_errors = {}
for ahead in aheads:
     region_df = price_error.query("REGIONID==@region")#.set_index("forecasted_time")
     for ahead in aheads:
         ahead_df = region_df[region_df["ahead_time"]==ahead]
         region_price_errors[ahead] = ahead_df

ahead_sort = np.sort(aheads)
first_ahead = ahead_sort[0]
rest_ahead = ahead_sort[1:]

first_region = region_price_errors[first_ahead]
first_region = first_region .iloc[1: , :]

error_matrix = pd.DataFrame()
error_matrix["forecasted_time"] = first_region["forecasted_time"]
error_matrix[first_ahead] = first_region["error"]

for r in rest_ahead:
    region_i = region_price_errors[r]
    region_i = region_i .iloc[1: , :]
    
    error_r = pd.DataFrame()
    error_r["forecasted_time"] = region_i["forecasted_time"]
    error_r[r] = region_i["error"]
    error_matrix=error_matrix.merge(error_r, on='forecasted_time', how='left', indicator=False)
     
error_matrix=error_matrix.dropna(axis=1)
error_mat_nums = error_matrix.iloc[:,1:]
col_names = list(error_mat_nums .columns)

error_means =  error_matrix.mean(axis=0)

N = len(error_mat_nums.columns)
error_cov = np.cov(error_mat_nums.T, bias=True)


######      STATISTICAL TESTS    #############

# tests for dependence
# Pearsons and rank correlations
error_corr_p = np.corrcoef(error_mat_nums.T)
error_corr_r,error_corr_r_pval = stats.spearmanr(error_mat_nums)

def f_test(x, y):
    x = np.array(x)
    y = np.array(y)
    f = np.var(x, ddof=1)/np.var(y, ddof=1) #calculate F test statistic 
    dfn = x.size-1 #define degrees of freedom numerator 
    dfd = y.size-1 #define degrees of freedom denominator 
    p = 1-scipy.stats.f.cdf(f, dfn, dfd) #find p-value of F test statistic 
    return f, p


f_test_stat = np.zeros((N,N))
f_test_p = np.zeros((N,N))
for m in range(N):
    for n in range(N):
        a = error_mat_nums.iloc[:,m]
        b = error_mat_nums.iloc[:,n]
        f_test_out = f_test(a,b)
        f_test_stat[m,n]=f_test_out[0]
        f_test_p[m,n]=f_test_out[1]

# Mutual information test and F-test
from sklearn.feature_selection import mutual_info_regression
N = len(error_mat_nums.columns)
error_mut_inf = np.zeros((N,N))

for n in range(N):
    a = error_mat_nums
    b = error_mat_nums.iloc[:,n]
    mut_inf_n = mutual_info_regression(a,b)
    error_mut_inf[n,:]=mut_inf_n 
    

## Tests for normality
# Skew and kurtosis - normal distribution should have close to zero skew and kurtosis
error_skew = stats.skew(error_mat_nums)
error_kurt = stats.kurtosis(error_mat_nums)

# Univariate Tests for Normality - Shapiro-Wilk test based on 95% confidence
# W statistic > 0.95 and p-value is > 0.05 it is possibly normal (fail to reject null hypothesis)
# W statistic < 0.95 and p-value is < 0.05 not normal (reject null hypothesis)
# where samples > 5000, the p-value may not be accurate
N = len(error_mat_nums.columns)
error_shap_W = np.zeros(N)
error_shap_p = np.zeros(N)
error_kol_stat = np.zeros(N)
error_kol_p = np.zeros(N)

for n in range(N):
    shap_n = stats.shapiro(error_mat_nums.iloc[:,n])
    error_shap_W[n] = shap_n[0]
    error_shap_p[n] = shap_n[1]
    kol_n = stats.kstest(error_mat_nums.iloc[:,n],'norm')
    error_kol_stat[n] = kol_n [0]
    error_kol_p[n] = kol_n [1]



## Multivariate Test for Normality - Henze-Zirkler Multivariate Normality Test
from pingouin import multivariate_normality
error_mult = multivariate_normality(error_mat_nums, alpha=.05)
hz=error_mult[0]
p_val=error_mult[1]

# create results subdirectory
import os
if not os.path.exists('results'):
   os.makedirs('results')

if not os.path.exists('results/plots'):
   os.makedirs('results/plots')


# saving of stats

error_means_df = pd.DataFrame(error_means )
error_means_df['ahead_time']=col_names
error_cov_df = pd.DataFrame(error_cov, columns=col_names)
error_cov_df['ahead_time']=col_names
error_corr_p_df = pd.DataFrame(error_corr_p, columns=col_names)
error_corr_p_df['ahead_time']=col_names
error_corr_r_df = pd.DataFrame(error_corr_r, columns=col_names)
error_corr_r_df['ahead_time']=col_names
f_test_stat_df = pd.DataFrame(f_test_stat, columns=col_names)
f_test_stat_df['ahead_time']=col_names
f_test_p_df = pd.DataFrame(f_test_p, columns=col_names)
f_test_p_df['ahead_time']=col_names
error_mut_inf_df = pd.DataFrame(error_mut_inf, columns=col_names)
error_mut_inf_df['ahead_time']=col_names
error_skew_df = pd.DataFrame(error_skew)
error_skew_df['ahead_time']=col_names
error_kurt_df = pd.DataFrame(error_kurt)
error_kurt_df['ahead_time']=col_names
error_shap_W_df = pd.DataFrame()
error_shap_W_df['shap_W'] = error_shap_W
error_shap_W_df['shap_p'] = error_shap_p
error_shap_W_df['ahead_time']=col_names
error_kol_df = pd.DataFrame()
error_kol_df['kol_stat'] = error_kol_stat
error_kol_df['kol_p'] = error_kol_p
error_kol_df['ahead_time']=col_names
error_mult_df = pd.DataFrame()
error_mult_df['stats_hz_p']=[hz, p_val]

error_means_df.to_csv("./results/error_means.csv")
error_cov_df.to_csv("./results/error_cov.csv")
error_corr_p_df.to_csv("./results/error_corr_p.csv")
error_corr_r_df.to_csv("./results/error_corr_r.csv")
error_skew_df.to_csv("./results/error_skew.csv")
error_kurt_df.to_csv("./results/error_kurt.csv")
error_mut_inf_df.to_csv("./results/error_mut_info.csv")
error_shap_W_df.to_csv("./results/error_uni_norm_shap.csv")
error_kol_df.to_csv("./results/error_uni_norm_kol.csv")
error_mult_df.to_csv("./results/error_mult_norm.csv")
f_test_stat_df.to_csv("./results/error_f_test_stat.csv")
f_test_p_df.to_csv("./results/error_f_test_p.csv")

# Price error probability plot

z=1
stats.probplot(error_mat_nums.iloc[:,z],dist="norm",plot=plt)
plt.show
savefig('./results/plots/prob_plot'+ str(z) + '.png')

for n in range(N):
    plt.clf()
    stats.probplot(error_mat_nums.iloc[:,n],dist="norm",plot=plt)
    plt.show
    plt.savefig('./results/plots/prob_plot'+ str(n) + '.png')
    