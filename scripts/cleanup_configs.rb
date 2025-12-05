#!/usr/bin/env ruby
# cleanup_configs.rb - Restructure assets folder to new layout
#
# Run from repository root:
#   ruby scripts/cleanup_configs.rb
#
# This script:
# 1. Creates new directory structure (greyscale/color style folders)
# 2. Moves and renames silhouettes (strips _shadow/_color suffixes)
# 3. Moves configs to new configs/ folder
# 4. Moves default files to silhouettes root
# 5. Removes old folders

require 'fileutils'

ASSETS_DIR = 'assets'
SILHOUETTES_DIR = File.join(ASSETS_DIR, 'silhouettes')
OLD_CONFIGS_DIR = File.join(ASSETS_DIR, 'silhouette_configs')
NEW_CONFIGS_DIR = File.join(ASSETS_DIR, 'configs')

# Map old style names to new
STYLE_MAP = {
  'shadow' => 'greyscale',
  'color' => 'color'
}

# Regions to process
REGIONS = %w[atoll hinterwilds hive moonsedge]

# Files/folders to exclude from processing
EXCLUDE_PATTERNS = [
  /\.xcf$/,           # GIMP source files
  /colors\.xcf$/,
  /shadows\.xcf$/
]

def excluded?(path)
  EXCLUDE_PATTERNS.any? { |pattern| path =~ pattern }
end

def strip_suffix(filename, suffix)
  # Remove _shadow or _color from filename
  # e.g., "assassin_shadow.png" -> "assassin.png"
  ext = File.extname(filename)
  base = File.basename(filename, ext)
  base.sub(/_#{suffix}$/, '') + ext
end

def restructure_assets
  puts "=" * 60
  puts "Restructuring assets folder to new layout"
  puts "=" * 60
  puts ""

  # Step 1: Create new directory structure
  puts "Step 1: Creating new directory structure..."

  # Create style/region folders for silhouettes
  %w[greyscale color].each do |style|
    REGIONS.each do |region|
      dir = File.join(SILHOUETTES_DIR, style, region)
      FileUtils.mkdir_p(dir)
      puts "  Created: #{dir}"
    end
  end

  # Create style/region folders for configs
  %w[greyscale color].each do |style|
    REGIONS.each do |region|
      dir = File.join(NEW_CONFIGS_DIR, style, region)
      FileUtils.mkdir_p(dir)
      puts "  Created: #{dir}"
    end
  end
  puts ""

  # Step 2: Move silhouettes from old structure to new
  puts "Step 2: Moving silhouettes..."

  Dir.glob(File.join(SILHOUETTES_DIR, '*')).each do |old_dir|
    next unless File.directory?(old_dir)
    folder_name = File.basename(old_dir)

    # Skip new structure folders
    next if %w[greyscale color].include?(folder_name)

    # Handle default folder specially
    if folder_name == 'default'
      puts "  Processing default folder..."
      Dir.glob(File.join(old_dir, '*.png')).each do |file|
        next if excluded?(file)
        filename = File.basename(file)

        if filename == 'default_shadow.png'
          # Move default_shadow.png to root as default.png
          dest = File.join(SILHOUETTES_DIR, 'default.png')
          FileUtils.cp(file, dest)
          puts "    Moved: #{filename} -> silhouettes/default.png"
        elsif filename =~ /^rank\d\.png$/ || filename == 'eyes_back_nerves.png'
          # Move rank files and overlay to root
          dest = File.join(SILHOUETTES_DIR, filename)
          FileUtils.cp(file, dest)
          puts "    Moved: #{filename} -> silhouettes/#{filename}"
        end
      end
      next
    end

    # Parse folder name: {region}_{style} or {region}_{style}_v{N}
    # e.g., atoll_shadow, atoll_shadow_v2, hinterwilds_color
    if folder_name =~ /^([a-z]+)_(shadow|color)(_v\d+)?$/
      region = $1
      old_style = $2
      version = $3 # may be nil
      new_style = STYLE_MAP[old_style]

      # For versioned folders, we only process the latest (non-versioned) one
      # Versioned folders are kept as-is for manifest archival purposes
      if version
        puts "  Skipping versioned folder: #{folder_name} (archived)"
        next
      end

      puts "  Processing: #{folder_name} -> #{new_style}/#{region}/"

      Dir.glob(File.join(old_dir, '*.png')).each do |file|
        next if excluded?(file)
        old_filename = File.basename(file)
        new_filename = strip_suffix(old_filename, old_style)

        dest = File.join(SILHOUETTES_DIR, new_style, region, new_filename)
        FileUtils.cp(file, dest)
        puts "    Moved: #{old_filename} -> #{new_style}/#{region}/#{new_filename}"
      end
    else
      puts "  Skipping unknown folder: #{folder_name}"
    end
  end
  puts ""

  # Step 3: Move configs from old structure to new
  puts "Step 3: Moving configs..."

  if File.directory?(OLD_CONFIGS_DIR)
    Dir.glob(File.join(OLD_CONFIGS_DIR, '*')).each do |old_dir|
      next unless File.directory?(old_dir)
      folder_name = File.basename(old_dir)

      # Handle default folder specially - move default.yaml to root level
      if folder_name == 'default'
        puts "  Processing default configs..."
        Dir.glob(File.join(old_dir, '*.yaml')).each do |file|
          next if excluded?(file)
          filename = File.basename(file)
          # Move default.yaml to configs root, not a subfolder
          dest = File.join(NEW_CONFIGS_DIR, filename)
          FileUtils.cp(file, dest)
          puts "    Moved: #{filename} -> configs/#{filename}"
        end
        next
      end

      # Parse folder name: {region}_{style}
      if folder_name =~ /^([a-z]+)_(shadow|color)$/
        region = $1
        old_style = $2
        new_style = STYLE_MAP[old_style]

        puts "  Processing: #{folder_name} -> #{new_style}/#{region}/"

        Dir.glob(File.join(old_dir, '*.yaml')).each do |file|
          next if excluded?(file)
          filename = File.basename(file)
          dest = File.join(NEW_CONFIGS_DIR, new_style, region, filename)
          FileUtils.cp(file, dest)
          puts "    Moved: #{filename} -> #{new_style}/#{region}/#{filename}"
        end
      else
        puts "  Skipping unknown folder: #{folder_name}"
      end
    end
  end
  puts ""

  # Step 4: Remove old folders
  puts "Step 4: Cleaning up old folders..."

  # Remove old silhouette folders (not versioned ones, keep those for archival)
  Dir.glob(File.join(SILHOUETTES_DIR, '*')).each do |old_dir|
    next unless File.directory?(old_dir)
    folder_name = File.basename(old_dir)

    # Keep new structure folders
    next if %w[greyscale color].include?(folder_name)

    # Keep versioned folders for archival
    next if folder_name =~ /_v\d+$/

    # Remove old-style folders (default, {region}_{style})
    if folder_name == 'default' || folder_name =~ /^[a-z]+_(shadow|color)$/
      FileUtils.rm_rf(old_dir)
      puts "  Removed: silhouettes/#{folder_name}/"
    end
  end

  # Remove old configs folder entirely
  if File.directory?(OLD_CONFIGS_DIR)
    FileUtils.rm_rf(OLD_CONFIGS_DIR)
    puts "  Removed: silhouette_configs/"
  end
  puts ""

  puts "=" * 60
  puts "Restructuring complete!"
  puts "=" * 60
  puts ""
  puts "New structure:"
  puts "  silhouettes/"
  puts "    default.png, rank1-3.png, eyes_back_nerves.png"
  puts "    greyscale/{region}/{creature}.png"
  puts "    color/{region}/{creature}.png"
  puts "  configs/"
  puts "    default.yaml"
  puts "    greyscale/{region}/{creature}.yaml"
  puts "    color/{region}/{creature}.yaml"
  puts ""
  puts "Next steps:"
  puts "  1. Run: ruby scripts/generate_manifest.rb"
  puts "  2. Commit the changes"
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

  restructure_assets
end
