#!/usr/bin/python3

# This script detects similar filenames for files of the same type (audio, video, etc.). Run with --help for usage instructions.

import os
import argparse
import difflib
import filetype

def search(root_dir, similarity_threshold, mime_substring, recurse=False, no_similar_extensions=False):
    if not os.path.exists(root_dir):
        print(f"{root_dir} does not exist, quitting...")
        return 1
    if not os.path.isdir(root_dir):
        print(f"{root_dir} is not a folder, quitting...")
        return 1
    
    f = []
    
    # Find files of the desired type
    for root, dirs, files in os.walk(root_dir):
        for filename in files:
            path = os.path.join(root, filename)
            kind = filetype.guess(path)
            if kind is not None:
                if mime_substring in kind.mime:
                    f.append({'filename': filename, 'path': path, 'extension': kind.extension})
        if not recurse:
            break
    
    total = len(f)
    print(f"Found {total} files of type {mime_substring} in {root_dir}")

    if not total:
        return 0

    for x in range(0, total-2):
        for y in range(x+1, total-1):
            if not no_similar_extensions and f[x]['extension'] == f[y]['extension']:
                similarity = filename_similarity(f[x]['filename'], f[y]['filename'])
                if similarity >= similarity_threshold:
                    print(f"{f[x]['path']}  |  {f[y]['path']}  ->  {similarity*100:.1f}%")

    return 0

# Compare similarity of filenames without extension
def filename_similarity(file1, file2):
    basename1 = os.path.splitext(file1)[0]
    basename2 = os.path.splitext(file2)[0]
    return difflib.SequenceMatcher(None, basename1, basename2).ratio()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Detect somewhat similar filenames for files of the same type (audio, video, image etc.) within a folder.")
    parser.add_argument("-r", "--recurse", action="store_true", help="Recurse into subfolders")
    parser.add_argument("-e", "--no_similar_extensions", action="store_true", help="Do not test similarity for files with the same extension (i.e. do not compare file1.mp3 to file2.mp3)")
    parser.add_argument("-s", "--similarity", type=float, help="Minimum level of similarity, where 1 is identity and 0 is complete dissimilarity (default is 0.8)", default=0.8)
    parser.add_argument("MIME_TYPE", type=str, help="MIME type substring (can be 'audio', 'audio/mp3', 'video' etc.), see https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types")
    parser.add_argument("FOLDER", type=str, help="Path to the folder to be searched for duplicates")
    
    args = parser.parse_args()

    exit_status = search(args.FOLDER, args.similarity, args.MIME_TYPE, args.recurse, args.no_similar_extensions)

    exit(exit_status)
