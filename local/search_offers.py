import json
import re
from fuzzywuzzy import process
import pandas as pd
from tabulate import tabulate
import subprocess

COLOR_RED = '\033[91m'
COLOR_RESET = '\033[0m'


# Function to load and extract data from JSON
def load_data_from_json(json_file):
    with open(json_file, "r") as file:
        data = json.load(file)

    extracted_data = {
        item[0]: item[1]
        for item in data["body"]
        if not (str(item[0]).startswith("2X") or str(item[0]).startswith("4X")) and bool(re.search(r'\d', item[0]))
    }
    return extracted_data


# Regular expression to clean CPU and GPU names
def clean_name(name):
    if name:
        name = re.sub(r'\b\d+-Cores?\b', '', name)
        name = re.sub(r'\bProcessor\b', '', name)
        name = re.sub(r'\bwith Radeon Graphics\b', '', name)
        name = re.sub(r'\bRyzen Threadripper\b', '', name)
        name = re.sub(r'\s+', ' ', name).strip()
    return name


# Function to extract numeric sequences from a string
def extract_numbers(name):
    return re.findall(r'\d+', name)


# Function to extract Xeon 'vx' generation
def extract_xeon_vx(name):
    match = re.search(r'\s+v(\d+)(\s+|$)', name)
    return match.group(1) if match else None


# Function to find the closest performance score based on name matching
def get_performance_score(orig_name, performance_data):
    if orig_name:
        name = clean_name(orig_name)
        numbers = extract_numbers(name)
        xeon_vx = extract_xeon_vx(name) if "Xeon" in name else None

        filtered_performance_data = {}

        # Filter by numbers first
        for num_count in [5, 4, 3, 2]:
            candidates = [num for num in numbers if len(num) == num_count]
            if candidates:
                for candidate in candidates:
                    filtered_performance_data = {
                        k: v for k, v in performance_data.items()
                        if candidate in k
                    }
                    if filtered_performance_data:
                        break
            if filtered_performance_data:
                break  # Stop if matches are found

        # Further filter by 'vX' if it is a Xeon processor
        if xeon_vx:
            vx_filtered = {
                k: v for k, v in filtered_performance_data.items()
                if f" v{xeon_vx}" in k
            }
            if vx_filtered:
                filtered_performance_data = vx_filtered
            else:
                return None  # No match for 'vx', return None

        # Apply fuzzy matching on the filtered data
        if filtered_performance_data:
            match = process.extractOne(name, list(filtered_performance_data.keys()), score_cutoff=70)
            if match:
                #print(f"Orig: {orig_name}, cleaned: {name}, compared_to: {match[0]} score: {match[1]}")
                return filtered_performance_data.get(match[0])

    return None


def get_results(search_string: list[str], orderby: str, to_std: bool = False):
    if orderby.startswith("g") or orderby.startswith("G"):
        sort_order = "GPU"
    elif orderby.startswith("$"):
        sort_order = "$/h"
    else:
        sort_order = "CPU"

        # Load CPU and GPU performance data
    cpu_performance_data = load_data_from_json("blender_data/cpu_json.json")
    gpu_performance_data = load_data_from_json("blender_data/gpu_json.json")

    # Load Vast AI listings
    """
    command = [
        "vastai", "search", "offers",
        "-o", "dph",
        # "-i",
        "cpu_cores_effective >= 16",
        "cpu_ram >= 32",
        "direct_port_count >= 1",
        "disk_space >= 20",
        "external = True",
        "gpu_arch = nvidia",
        "gpu_ram >= 12",
        "inet_down >= 300",
        "inet_up >= 300",
        # "inet_up_cost <= 0.0004",
        # "inet_down_cost <= 0.0004",
        "rentable = True",
        "duration >= 1",
        "verified = True",
        "geolocation not in ['DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'EH', 'ZM', 'ZW', 'AF', 'AM', 'AZ', 'BH', 'BD', 'BT', 'BN', 'KH', 'CN', 'CY', 'GE', 'IN', 'ID', 'IR', 'IQ', 'IL', 'JP', 'JO', 'KZ', 'KW', 'KG', 'LA', 'LB', 'MY', 'MV', 'MN', 'MM', 'NP', 'OM', 'PK', 'PH', 'QA', 'SA', 'SG', 'KR', 'LK', 'SY', 'TJ', 'TH', 'TL', 'TR', 'TM', 'AE', 'UZ', 'VN', 'YE']",
        "--limit", "1000",
        "--raw"
    ]
    """

    # Run the command and capture the output
    result = subprocess.run(search_string, capture_output=True, text=True, check=True)

    # Parse the output as JSON
    vastai_listings = json.loads(result.stdout)

    results = []
    for listing in vastai_listings:
        cpu_name = listing.get('cpu_name')
        gpu_name = listing.get('gpu_name')

        cpu_name_clean = clean_name(cpu_name)
        gpu_name_clean = clean_name(gpu_name)

        cpu_performance = get_performance_score(cpu_name_clean, cpu_performance_data) if cpu_name else None
        gpu_performance = get_performance_score(gpu_name_clean, gpu_performance_data) if gpu_name else None

        if cpu_performance:
            adj_cpu_performance = listing['cpu_cores_effective'] / listing['cpu_cores'] * cpu_performance
            cpu_perf_per_buck = round(adj_cpu_performance / listing['dph_base'], 2)
        else:
            adj_cpu_performance = None
            cpu_perf_per_buck = None
            continue

        if gpu_performance:
            adjusted_gpu_performance = listing['num_gpus'] * listing['gpu_frac'] * gpu_performance
            gpu_perf_per_buck = round(adjusted_gpu_performance / listing['dph_base'], 2)
            total_flops_adjusted = round(listing['total_flops'] * listing['gpu_frac'], 2)
        else:
            adjusted_gpu_performance = None
            gpu_perf_per_buck = None
            total_flops_adjusted = None
            continue

        if total_flops_adjusted and listing['total_flops'] > 0:
            percentage_lost = round(((listing['total_flops'] - total_flops_adjusted) / listing['total_flops']) * 100, 2)
        else:
            percentage_lost = 0  # Handle division by zero or no flops reported

        results.append({
            "ID": listing['id'],
            "$/h": listing['dph_base'],
            "CPU Name": cpu_name_clean,
            "Ajd. CPU Perf.": adj_cpu_performance,
            "CPU Perf/$": cpu_perf_per_buck,
            "GPU Name": str(round(listing['num_gpus'], 1)) + "x" + str(
                round(listing['gpu_frac'], 1)) + "x " + gpu_name_clean,
            "Adj. GPU Perf.": adjusted_gpu_performance,
            "GPU Perf/$": gpu_perf_per_buck,
            "Net down:": listing['inet_down'],
            "Net up:": listing['inet_up'],
        })

    # Creating a DataFrame for display
    df = pd.DataFrame(results)

    # Sorting
    # Change to 'GPU' to sort by GPU performance per buck
    if sort_order == 'CPU':
        df = df.sort_values(by=['CPU Perf/$', 'GPU Perf/$'], ascending=[False, False])
    elif sort_order == 'GPU':
        df = df.sort_values(by=['GPU Perf/$', 'CPU Perf/$'], ascending=[False, False])
    elif sort_order == 'dph':  # Per hour cost
        df = df.sort_values(by=['$/h'], ascending=True)

    df.reset_index(drop=True, inplace=True)  # Resets the index without adding a new column and drops the old index
    df.insert(0, 'num', df.index + 1)  # Inserts 'num' at the first position (index 0)

    def colorize_column(df, column_name, color_code):
        df[column_name] = df[column_name].apply(lambda x: f"{color_code}{x}{COLOR_RESET}")
        return df

    # Colorize "CPU Perf/$" and "GPU Perf/$" columns
    df: df = colorize_column(df, "CPU Perf/$", COLOR_RED)
    df: df = colorize_column(df, "GPU Perf/$", COLOR_RED)

    # Print table using tabulate
    if to_std:
        print(tabulate(df, headers='keys', tablefmt='pipe', showindex=False))
    else:
        return df

    return


if __name__ == "__main__":
    sort_order = input("GPU or CPU listings: ")

    get_results(sort_order, to_std=True)
