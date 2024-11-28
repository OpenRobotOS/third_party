# third_party

## Usage
./install.sh

1 for download \
2 for install


## add global cmake flag
- example: add_global_cmake_flag "-O3 -march=native"

## add global cmake config
- example: add_global_cmake_config "-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX -DCMAKE_PREFIX_PATH=$PREFIX_PATH"

## Adding repositories directly in the script
add_repo "name" "url" "tag" "cmake_flag" "cmake_config" "custom_install"
- example: add_repo "name" "url" "tag" "cmake_flag" "cmake_config" "custom_install"
