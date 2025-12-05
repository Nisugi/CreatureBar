#!/usr/bin/env ruby
# generate_manifest.rb - Generates manifest.json for Jinx asset distribution
#
# Run from repository root:
#   ruby scripts/generate_manifest.rb
#
# This scans the assets/ directory and creates a manifest.json with SHA1 digests
# for each file, organized by package.
#
# New folder structure:
#   assets/silhouettes/default.png, rank1.png, eyes_back_nerves.png (root level)
#   assets/silhouettes/{style}/{region}[_v#]/{family}.png
#   assets/configs/default.yaml (root level)
#   assets/configs/{style}/{region}[_v#]/{family}.yaml
#
# Package naming:
#   - Root files: creaturebar-default
#   - Region files: creaturebar-{style}-{region}[-v#]
#   - Example: greyscale/hinterwilds_v2 -> creaturebar-greyscale-hinterwilds-v2

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
  /colors\.xcf$/,     # Work files
  /shadows\.xcf$/     # Work files
]

# Convert style/region folder to package name
# e.g., 'greyscale', 'hinterwilds_v2' -> 'creaturebar-greyscale-hinterwilds-v2'
def folder_to_package(style, region)
  # Convert underscores to hyphens for package name
  "creaturebar-#{style}-#{region.gsub('_', '-')}"
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

def add_asset(assets, file_path, package_name)
  return if excluded?(file_path)

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

def scan_assets
  assets = []

  # --- Silhouettes ---

  # Root level silhouettes (default.png, rank*.png, eyes_back_nerves.png)
  Dir.glob(File.join(ASSETS_DIR, 'silhouettes', '*.png')).each do |file_path|
    add_asset(assets, file_path, 'creaturebar-default')
  end

  # Style/region silhouettes: silhouettes/{style}/{region}/*.png
  Dir.glob(File.join(ASSETS_DIR, 'silhouettes', '*', '*', '*.png')).each do |file_path|
    next if excluded?(file_path)

    # Extract style and region from path
    # e.g., assets/silhouettes/greyscale/hinterwilds_v2/valravn.png
    parts = file_path.split(File::SEPARATOR)
    style = parts[-3]   # greyscale or color
    region = parts[-2]  # hinterwilds, atoll, hinterwilds_v2, etc.

    package_name = folder_to_package(style, region)
    add_asset(assets, file_path, package_name)
  end

  # --- Configs ---

  # Root level config (default.yaml)
  Dir.glob(File.join(ASSETS_DIR, 'configs', '*.yaml')).each do |file_path|
    add_asset(assets, file_path, 'creaturebar-default')
  end

  # Style/region configs: configs/{style}/{region}/*.yaml
  Dir.glob(File.join(ASSETS_DIR, 'configs', '*', '*', '*.yaml')).each do |file_path|
    next if excluded?(file_path)

    # Extract style and region from path
    parts = file_path.split(File::SEPARATOR)
    style = parts[-3]
    region = parts[-2]

    package_name = folder_to_package(style, region)
    add_asset(assets, file_path, package_name)
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
    configs = pkg_assets.count { |a| a['file'].include?('/configs/') }
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
