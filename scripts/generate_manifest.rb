#!/usr/bin/env ruby
# generate_manifest.rb - Generates manifest.json for Jinx asset distribution
#
# Run from repository root:
#   ruby scripts/generate_manifest.rb
#
# This scans the assets/ directory and creates a manifest.json with SHA1 digests
# for each file, organized by package (creaturebar-default, creaturebar-hinterwilds-shadow, etc.)
#
# Folder naming convention:
#   - Folders can have version suffixes (e.g., hinterwilds_shadow_v2)
#   - Package names are derived by stripping version suffix and prefixing with 'creaturebar-'
#   - Example: hinterwilds_shadow_v2 -> creaturebar-hinterwilds-shadow

require 'json'
require 'digest'
require 'base64'
require 'fileutils'

# Configuration
ASSETS_DIR = 'assets'
OUTPUT_FILE = 'manifest.json'

# Files/folders to exclude from manifest (source files, work-in-progress)
EXCLUDE_PATTERNS = [
  /\.xcf$/,           # GIMP source files
  /_v1\//,            # Old versions (only include latest v2)
  /colors\.xcf$/,     # Work files
  /hinterwilds_shadow\//, # Older non-versioned hinterwilds (use v2 instead)
  /atoll_shadow_v1\// # Old atoll v1 (use v2 instead)
]

# Convert folder name to package name
# e.g., 'hinterwilds_shadow_v2' -> 'creaturebar-hinterwilds-shadow'
def folder_to_package(folder_name)
  # Strip version suffix (_v1, _v2, etc.)
  base_name = folder_name.sub(/_v\d+$/, '')
  # Convert underscores to hyphens for package name
  "creaturebar-#{base_name.gsub('_', '-')}"
end

def calculate_sha1_base64(file_path)
  digest = Digest::SHA1.new
  File.open(file_path, 'rb') do |f|
    while chunk = f.read(8192)
      digest.update(chunk)
    end
  end
  digest.base64digest
end

def excluded?(file_path)
  EXCLUDE_PATTERNS.any? { |pattern| file_path =~ pattern }
end

def scan_assets
  assets = []

  # Scan silhouettes (PNG files in subfolders)
  Dir.glob(File.join(ASSETS_DIR, 'silhouettes', '*', '*.png')).each do |file_path|
    next if excluded?(file_path)

    # Extract pack name from path (e.g., assets/silhouettes/hinterwilds_shadow_v2/warg_shadow.png)
    parts = file_path.split(File::SEPARATOR)
    pack_dir = parts[-2]  # Directory name (default, hinterwilds_shadow_v2, etc.)

    package_name = folder_to_package(pack_dir)

    # Convert to forward slashes for manifest (cross-platform)
    relative_path = file_path.gsub('\\', '/')

    assets << {
      'file' => "/#{relative_path}",
      'type' => 'data',
      'md5' => calculate_sha1_base64(file_path),  # Jinx uses 'md5' key but accepts SHA1
      'last_commit' => File.mtime(file_path).to_i,
      'package' => package_name
    }

    puts "  Added: #{relative_path} (#{package_name})"
  end

  # Scan silhouette configs (YAML files in subfolders)
  Dir.glob(File.join(ASSETS_DIR, 'silhouette_configs', '*', '*.yaml')).each do |file_path|
    next if excluded?(file_path)

    parts = file_path.split(File::SEPARATOR)
    pack_dir = parts[-2]

    package_name = folder_to_package(pack_dir)

    relative_path = file_path.gsub('\\', '/')

    assets << {
      'file' => "/#{relative_path}",
      'type' => 'data',
      'md5' => calculate_sha1_base64(file_path),
      'last_commit' => File.mtime(file_path).to_i,
      'package' => package_name
    }

    puts "  Added: #{relative_path} (#{package_name})"
  end

  assets
end

def generate_manifest
  puts "Scanning assets directory..."
  puts ""

  assets = scan_assets

  manifest = {
    'available' => assets,
    'last_updated' => Time.now.to_i
  }

  # Write manifest
  File.write(OUTPUT_FILE, JSON.pretty_generate(manifest))

  puts ""
  puts "=" * 60
  puts "Manifest generated: #{OUTPUT_FILE}"
  puts "Total assets: #{assets.size}"
  puts ""

  # Summary by package
  packages = assets.group_by { |a| a['package'] }
  packages.each do |pkg, pkg_assets|
    silhouettes = pkg_assets.count { |a| a['file'].include?('/silhouettes/') }
    configs = pkg_assets.count { |a| a['file'].include?('/silhouette_configs/') }
    puts "  #{pkg}: #{silhouettes} silhouettes, #{configs} configs"
  end

  puts ""
  puts "Last updated: #{Time.at(manifest['last_updated'])}"
end

# Run if executed directly
if __FILE__ == $0
  # Change to repo root if running from scripts/
  if File.basename(Dir.pwd) == 'scripts'
    Dir.chdir('..')
  end

  unless File.directory?(ASSETS_DIR)
    puts "Error: #{ASSETS_DIR}/ directory not found"
    puts "Run this script from the repository root"
    exit 1
  end

  generate_manifest
end
