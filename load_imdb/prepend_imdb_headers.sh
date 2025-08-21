#!/bin/bash

# Copyright 2022 The Balsa Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Prepends column names to headerless IMDB CSVs.

# Default CSV directory
CSV_DIR=${1:-"/home/qihan/load_imdb/datasets/job"}

# Function to prepend a line to a file
prepend_line() {
    local filename="$1"
    local line="$2"
    
    if [[ -f "$filename" ]]; then
        # Create a temporary file
        local temp_file=$(mktemp)
        # Write the header line first
        echo "$line" > "$temp_file"
        # Append the original content
        cat "$filename" >> "$temp_file"
        # Replace the original file
        mv "$temp_file" "$filename"
    else
        echo "Warning: File $filename not found, skipping..."
    fi
}

# Main function
main() {
    echo "Processing IMDB CSV files in directory: $CSV_DIR"
    
    # Check if directory exists
    if [[ ! -d "$CSV_DIR" ]]; then
        echo "Error: Directory $CSV_DIR does not exist"
        exit 1
    fi
    
    # Column names for http://homepages.cwi.nl/~boncz/job/imdb.tgz.
    # Process each table with its columns
    prepend_line "$CSV_DIR/aka_name.csv" "id,person_id,name,imdb_index,name_pcode_cf,name_pcode_nf,surname_pcode,md5sum"
    
    prepend_line "$CSV_DIR/aka_title.csv" "id,movie_id,title,imdb_index,kind_id,production_year,phonetic_code,episode_of_id,season_nr,episode_nr,note,md5sum"
    
    prepend_line "$CSV_DIR/cast_info.csv" "id,person_id,movie_id,person_role_id,note,nr_order,role_id"
    
    prepend_line "$CSV_DIR/char_name.csv" "id,name,imdb_index,imdb_id,name_pcode_nf,surname_pcode,md5sum"
    
    prepend_line "$CSV_DIR/company_name.csv" "id,name,country_code,imdb_id,name_pcode_nf,name_pcode_sf,md5sum"
    
    prepend_line "$CSV_DIR/company_type.csv" "id,kind"
    
    prepend_line "$CSV_DIR/comp_cast_type.csv" "id,kind"
    
    prepend_line "$CSV_DIR/complete_cast.csv" "id,movie_id,subject_id,status_id"
    
    prepend_line "$CSV_DIR/info_type.csv" "id,info"
    
    prepend_line "$CSV_DIR/keyword.csv" "id,keyword,phonetic_code"
    
    prepend_line "$CSV_DIR/kind_type.csv" "id,kind"
    
    prepend_line "$CSV_DIR/link_type.csv" "id,link"
    
    prepend_line "$CSV_DIR/movie_companies.csv" "id,movie_id,company_id,company_type_id,note"
    
    prepend_line "$CSV_DIR/movie_info.csv" "id,movie_id,info_type_id,info,note"
    
    prepend_line "$CSV_DIR/movie_info_idx.csv" "id,movie_id,info_type_id,info,note"
    
    prepend_line "$CSV_DIR/movie_keyword.csv" "id,movie_id,keyword_id"
    
    prepend_line "$CSV_DIR/movie_link.csv" "id,movie_id,linked_movie_id,link_type_id"
    
    prepend_line "$CSV_DIR/name.csv" "id,name,imdb_index,imdb_id,gender,name_pcode_cf,name_pcode_nf,surname_pcode,md5sum"
    
    prepend_line "$CSV_DIR/person_info.csv" "id,person_id,info_type_id,info,note"
    
    prepend_line "$CSV_DIR/role_type.csv" "id,role"
    
    prepend_line "$CSV_DIR/title.csv" "id,title,imdb_index,kind_id,production_year,imdb_id,phonetic_code,episode_of_id,season_nr,episode_nr,series_years,md5sum"
    
    echo "Finished processing all IMDB CSV files"
}

# Run main function
main "$@"
