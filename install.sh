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

    if [ -z "$name" ] || [ -z "$url" ] || [ -z "$tag" ]; then
        echo "Usage: add_repo <name> <url> <tag> <cmake_config> <cmake_flag>"
        return 1
    fi

    # Store the repository URL and tag
    REPOS["$name,url"]="$url"
    REPOS["$name,tag"]="$tag"
    REPOS["$name,cmake_config"]="$cmake_config"  
    REPOS["$name,cmake_flag"]="$cmake_flag"  

    echo "Repository '$name' with URL '$url', tag '$tag', CMake config '$cmake_config',and CMake flag '$cmake_flag' added."
}

# global cmake config
function add_global_cmake_config() {
    GLOBAL_CMAKE_CONFIG="$1"
}
function add_global_cmake_flag() {
    GLOBAL_CMAKE_FLAG="$1"
}

add_global_cmake_flag "-O3 -march=native"
add_global_cmake_config "-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/openrobotlib"
# Adding repositories directly in the script
add_repo "yaml-cpp" "https://github.com/jbeder/yaml-cpp.git" "0.8.0" "" ""
add_repo "spdlog" "https://github.com/gabime/spdlog.git" "v1.15.0" "" ""
add_repo "lcm" "https://github.com/lcm-proj/lcm.git" "v1.5.0" "" ""

# Function to download all repositories
function download() {
    echo "Downloading..."

    # Prompt the user to choose an option
    echo "Please choose an option:"
    echo "1. Download all repositories"
    echo "2. Choose a single repository to download"
    read -p "Enter your choice (1 or 2): " choice

    # Change to the _dep folder
    cd "$DEP_FOLDER"

    if [ "$choice" == "1" ]; then
        # Option 1: Download all repositories
        echo "Downloading all repositories..."
        for repo_name in "${!REPOS[@]}"; do
            if [[ "$repo_name" == *",url" ]]; then
                # Extract the repository name, URL, and tag
                name="${repo_name%,url}"
                url="${REPOS[$repo_name]}"
                tag="${REPOS["$name,tag"]}"
                # Check if the directory exists and remove it if necessary
                if [ -d "$name" ]; then
                    echo "Directory '$name' exists. Removing it..."
                    rm -rf "$name"  # Forcefully remove the existing directory
                fi
                echo "Cloning $name from $url with tag $tag..."
                git clone --branch "$tag" "$url" "$name"
            fi
        done
    elif [ "$choice" == "2" ]; then
        # Option 2: Choose a specific repository to download
        echo "Please choose a repository to download:"
        repo_names=()
        i=1
        # Build the list of repository names
        for repo_name in "${!REPOS[@]}"; do
            if [[ "$repo_name" == *",url" ]]; then
                name="${repo_name%,url}"
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
        git clone --branch "$tag" "$url" "$selected_name"
    else
        echo "Invalid option. Download operation aborted."
    fi

    # Return to the script's original directory
    cd "$SCRIPT_DIR"
    echo "Download complete."
}



# Function to install
# Function to install
function install() {
    echo "Installing..."

    # Prompt the user to choose an option
    echo "Please choose an option:"
    echo "1. Install all repositories"
    echo "2. Choose a specific repository to install"
    read -p "Enter your choice (1 or 2): " choice

    # Option 1: Install all repositories
    if [ "$choice" == "1" ]; then
        echo "Installing all repositories..."
        
        # Traverse each subdirectory inside _dep
        for dir in "$DEP_FOLDER"/*; do
            if [ -d "$dir" ]; then
                repo_name=$(basename "$dir")

                echo "Configuring and building repository: $repo_name"
                mkdir -p "$dir/build"  # Create a build directory
                cd "$dir/build"  # Move to the build directory
                # Add repository-specific configuration from REPOS
                cmake_config="${REPOS["$repo_name,cmake_config"]}"
                cmake_flag="${REPOS["$repo_name,cmake_flag"]}"
                cmake .. $GLOBAL_CMAKE_CONFIG $cmake_config -DCMAKE_CXX_FLAGS="$GLOBAL_CMAKE_FLAG $cmake_flag"
                # Compile the repository
                make -j$(nproc) # Use all available cores for faster build

                # Install the repository
                sudo make install

                # Return to the script's root directory
                cd "$SCRIPT_DIR"
            fi
        done
        echo "All repositories installed."

    # Option 2: Install a specific repository
    elif [ "$choice" == "2" ]; then
        echo "Please choose a repository to install:"
        repo_names=()
        i=1

        # Build the list of repository names
        for repo_name in "${!REPOS[@]}"; do
            if [[ "$repo_name" == *",url" ]]; then
                name="${repo_name%,url}"
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
            echo "Configuring and building repository: $selected_name"
            mkdir -p "$selected_dir/build"  # Create a build directory
            cd "$selected_dir/build"  # Move to the build directory

            # Add repository-specific configuration from REPOS
            cmake_config="${REPOS["$selected_name,cmake_config"]}"
            cmake_flag="${REPOS["$selected_name,cmake_flag"]}"
            cmake .. $GLOBAL_CMAKE_CONFIG $cmake_config -DCMAKE_CXX_FLAGS="$GLOBAL_CMAKE_FLAG $cmake_flag"


            # Compile the repository
            make -j$(nproc)  # Use all available cores for faster build

            # Install the repository
            sudo make install

            # Return to the script's root directory
            cd "$SCRIPT_DIR"
        else
            echo "Invalid repository selected. Installation aborted."
            return 1
        fi

        echo "$selected_name installed."

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
