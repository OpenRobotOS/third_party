#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DEP_FOLDER="$SCRIPT_DIR/_dep"
GLOBAL_CMAKE_CONFIG=""
GLOBAL_CMAKE_FLAG=""
if [ ! -d "$DEP_FOLDER" ]; then
    mkdir "$DEP_FOLDER"
    echo "_dep 文件夹已创建在 $SCRIPT_DIR"
else
    echo "_dep 文件夹已经存在"
fi

# Declare an associative array to store repository information
declare -A REPOS

# Function to add a new repository URL with a tag and CMake configurations
function add_repo() {
    local name="$1"
    local url="$2"
    local tag="$3"
    local cmake_config="${4:-default_config}"
    local cmake_flag="${5}"
    local custom_install="${6:-}"

    if [ -z "$name" ] || [ -z "$url" || [ -z "$tag" ]; then
        echo "Usage: add_repo <name> <url> <tag> <cmake_config> <cmake_flag> [custom_install]"
        return 1
    fi

    # Store the repository URL and tag
    REPOS["$name,url"]="$url"
    REPOS["$name,tag"]="$tag"
    REPOS["$name,cmake_config"]="$cmake_config"
    REPOS["$name,cmake_flag"]="$cmake_flag"
    REPOS["$name,custom_install"]="$custom_install"

    echo "Repository '$name' with URL '$url', tag '$tag', CMake config '$cmake_config', CMake flag '$cmake_flag', and custom install '$custom_install' added."
}

# Global cmake config
function add_global_cmake_config() {
    GLOBAL_CMAKE_CONFIG="$1"
}
function add_global_cmake_flag() {
    GLOBAL_CMAKE_FLAG="$1"
}

INSTALL_PREFIX="/opt/openrobotlib/third_party"
PREFIX_PATH="/opt/openrobotlib/third_party"

add_global_cmake_flag "-O3 -march=native"
add_global_cmake_config "-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX -DCMAKE_PREFIX_PATH=$PREFIX_PATH"

# Adding repositories directly in the script
add_repo "yaml-cpp" "https://github.com/jbeder/yaml-cpp.git" "0.8.0" "" "" ""
add_repo "spdlog" "https://github.com/gabime/spdlog.git" "v1.15.0" "-DSPDLOG_USE_STD_FORMAT=ON -DSPDLOG_BUILD_SHARED=ON -DSPDLOG_BUILD_PIC=ON" "" ""
add_repo "lcm" "https://github.com/lcm-proj/lcm.git" "v1.5.0" "" "" ""
add_repo "boost" "https://github.com/boostorg/boost.git" "boost-1.86.0" "" "" "install_boost_lib"

# Function to download all repositories
function download() {
    echo "Downloading..."

    # Prompt the user to choose an option
    echo "Please choose an option:"
    echo "1. Download all repositories"
    echo "2. Choose a single repository to download"
    read -p "Enter your choice (1 or 2): " choice

    # Change to the _dep folder
    cd "$DEP_FOLDER" || exit

    if [ "$choice" == "1" ]; then
        # Option 1: Download all repositories
        echo "Downloading all repositories..."
        for repo_key in "${!REPOS[@]}"; do
            if [[ "$repo_key" == *",url" ]]; then
                # Extract the repository name, URL, and tag
                name="${repo_key%,url}"
                url="${REPOS[$repo_key]}"
                tag="${REPOS["$name,tag"]}"
                # Check if the directory exists and remove it if necessary
                if [ -d "$name" ]; then
                    echo "Directory '$name' exists. Removing it..."
                    rm -rf "$name"  # Forcefully remove the existing directory
                fi
                echo "Cloning $name from $url with tag $tag..."
                git clone --recursive --branch "$tag" "$url" "$name"
            fi
        done
    elif [ "$choice" == "2" ]; then
        # Option 2: Choose a specific repository to download
        echo "Please choose a repository to download:"
        repo_names=()
        i=1
        # Build the list of repository names
        for repo_key in "${!REPOS[@]}"; do
            if [[ "$repo_key" == *",url" ]]; then
                name="${repo_key%,url}"
                repo_names+=("$i. $name")
                i=$((i+1))
            fi
        done

        # Display the list of repositories for the user to choose from
        for repo in "${repo_names[@]}"; do
            echo "$repo"
        done

        # Get the user's choice
        read -p "Enter the repository number: " repo_choice
        selected_repo="${repo_names[$repo_choice-1]}"
        selected_name=$(echo "$selected_repo" | sed 's/^[0-9]*\. //')

        # Get the URL and tag for the selected repository
        url="${REPOS["$selected_name,url"]}"
        tag="${REPOS["$selected_name,tag"]}"

        if [ -d "$selected_name" ]; then
            echo "Directory '$selected_name' exists. Removing it..."
            rm -rf "$selected_name"  # Forcefully remove the existing directory
        fi
        # Download the selected repository
        echo "Cloning repository $selected_name from $url with tag $tag..."
        git clone --recursive --branch "$tag" "$url" "$selected_name"
    else
        echo "Invalid option. Download operation aborted."
    fi

    # Return to the script's original directory
    cd "$SCRIPT_DIR" || exit
    echo "Download complete."
}

# Function to install
function install_repo() {
    local repo_name="$1"
    local repo_dir="$DEP_FOLDER/$repo_name"
    local custom_install="${REPOS["$repo_name,custom_install"]}"

    if [ -n "$custom_install" ]; then
        # 调用自定义安装函数
        if declare -f "$custom_install" > /dev/null; then
            echo "执行自定义安装函数: $custom_install"
            "$custom_install" "$repo_dir"
        else
            echo "自定义安装函数 '$custom_install' 未定义。使用默认安装流程。"
            default_install "$repo_dir" "$repo_name"
        fi
    else
        # 使用默认安装流程
        default_install "$repo_dir" "$repo_name"
    fi
}

# Default install function
function default_install() {
    local repo_dir="$1"
    local repo_name="$2"

    echo "Configuring and building repository: $repo_name"
    mkdir -p "$repo_dir/build"  # Create a build directory
    cd "$repo_dir/build" || exit 1  # Move to the build directory
    # Add repository-specific configuration from REPOS
    cmake_config="${REPOS["$repo_name,cmake_config"]}"
    cmake_flag="${REPOS["$repo_name,cmake_flag"]}"
    cmake .. $GLOBAL_CMAKE_CONFIG $cmake_config -DCMAKE_CXX_FLAGS="$GLOBAL_CMAKE_FLAG $cmake_flag"
    # Compile the repository
    make -j"$(nproc)" # Use all available cores for faster build

    # Install the repository
    sudo make install

    # Return to the script's root directory
    cd "$SCRIPT_DIR" || exit
}

# Example of a custom install function
function install_boost_lib() {
    local repo_dir="$1"
    echo "执行 boost 的自定义安装流程"
    cd "$repo_dir" || exit
    sudo ./bootstrap.sh --prefix=$INSTALL_PREFIX
    sudo ./b2 install
    cd "$SCRIPT_DIR" || exit
}

function install_all() {
    echo "Installing all repositories..."

    # Traverse each subdirectory inside _dep
    for dir in "$DEP_FOLDER"/*; do
        if [ -d "$dir" ]; then
            repo_name=$(basename "$dir")
            install_repo "$repo_name"
        fi
    done
    echo "All repositories installed."
}

function install_specific() {
    echo "Please choose a repository to install:"
    repo_names=()
    i=1

    # Build the list of repository names
    for repo_key in "${!REPOS[@]}"; do
        if [[ "$repo_key" == *",url" ]]; then
            name="${repo_key%,url}"
            repo_names+=("$i. $name")
            i=$((i+1))
        fi
    done

    # Display the list of repositories for the user to choose from
    for repo in "${repo_names[@]}"; do
        echo "$repo"
    done

    # Get the user's choice
    read -p "Enter the repository number: " repo_choice
    selected_repo="${repo_names[$repo_choice-1]}"
    selected_name=$(echo "$selected_repo" | sed 's/^[0-9]*\. //')

    # Check if the selected repository exists in _dep
    selected_dir="$DEP_FOLDER/$selected_name"
    if [ -d "$selected_dir" ]; then
        install_repo "$selected_name"
    else
        echo "Invalid repository selected. Installation aborted."
        return 1
    fi

    echo "$selected_name 安装完成。"
}

function install() {
    echo "Installing..."

    # Prompt the user to choose an option
    echo "Please choose an option:"
    echo "1. Install all repositories"
    echo "2. Choose a specific repository to install"
    read -p "Enter your choice (1 or 2): " choice

    if [ "$choice" == "1" ]; then
        install_all
    elif [ "$choice" == "2" ]; then
        install_specific
    else
        echo "Invalid option. Installation aborted."
    fi

    echo "Installation complete."
}

# Prompt user for input
echo "Please choose an option:
      1. download
      2. install"
read choice

# Check the user input
if [ "$choice" == "1" ]; then
    download
elif [ "$choice" == "2" ]; then
    install
else
    echo "Invalid option. Please choose either '1' or '2'."
    exit 1
fi
