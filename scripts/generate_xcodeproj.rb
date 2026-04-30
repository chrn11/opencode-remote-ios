#!/usr/bin/env ruby
# generate_xcodeproj.rb — 在无 Xcode 环境下程序化生成 .xcodeproj（xcodeproj gem 标准用法）
# 创建时间：2026-04-30
# 技术注意：target.add_file_references 不存在，必须手动操作 source_build_phase.add_file_reference

require 'xcodeproj'

APP_NAME   = 'OpenCodeRemote'
BUNDLE_ID  = 'com.opencode.remote'
DEPLOYMENT_TARGET = '17.0'
TEAM_ID    = ENV['APPLE_TEAM_ID'] || ''

# -----------------------------------------------------------
# 1. 项目 & target
# -----------------------------------------------------------
project = Xcodeproj::Project.new("#{APP_NAME}.xcodeproj")

# 全局 build settings
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  config.build_settings['SWIFT_VERSION']             = '5.9'
  config.build_settings['CODE_SIGN_STYLE']             = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM']           = TEAM_ID
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']  = BUNDLE_ID
  config.build_settings['ENABLE_BITCODE']            = 'NO'
  config.build_settings['SDKROOT']                   = 'iphoneos'
  config.build_settings['TARGETED_DEVICE_FAMILY']    = '1,2'
end

# 创建 iOS App target
target = project.new_target(:application, APP_NAME, :ios, DEPLOYMENT_TARGET, nil, BUNDLE_ID)

# target 级 build settings
target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  config.build_settings['SWIFT_VERSION']             = '5.9'
  config.build_settings['INFOPLIST_FILE']            = "#{APP_NAME}/Info.plist"
  config.build_settings['PRODUCT_NAME']              = APP_NAME
end

# -----------------------------------------------------------
# 2. 建立 group 树 & 文件引用
# -----------------------------------------------------------
main_group = project.main_group

# 递归创建 group，返回叶子 group
def ensure_groups(parent_group, relative_path)
  parts = relative_path.split('/')
  current = parent_group
  parts.each do |part|
    next if part == '.' || part == ''
    existing = current[part]
    current = existing ? existing : current.new_group(part, part)
  end
  current
end

# 扫描源文件 & 资源
source_files = Dir.glob("#{APP_NAME}/**/*.swift").sort
plist_files  = Dir.glob("#{APP_NAME}/**/*.plist").sort
asset_dirs   = Dir.glob("#{APP_NAME}/Assets.xcassets").sort

# 创建根 group
root_group = main_group[APP_NAME] || main_group.new_group(APP_NAME, APP_NAME)

source_files.each do |file_path|
  relative = file_path.sub("#{APP_NAME}/", '')
  dir_part = File.dirname(relative)
  group = dir_part == '.' ? root_group : ensure_groups(root_group, dir_part)
  # 文件引用路径必须是相对于该 group 的，否则路径会重复嵌套
  ref = group.new_file(File.basename(relative))
  target.source_build_phase.add_file_reference(ref)
end

plist_files.each do |file_path|
  relative = file_path.sub("#{APP_NAME}/", '')
  # Info.plist 已通过 INFOPLIST_FILE 设置，不可重复加入 Resources
  next if relative == 'Info.plist'
  dir_part = File.dirname(relative)
  group = dir_part == '.' ? root_group : ensure_groups(root_group, dir_part)
  ref = group.new_file(File.basename(relative))
  target.resources_build_phase.add_file_reference(ref)
end

asset_dirs.each do |dir|
  relative = dir.sub("#{APP_NAME}/", '')
  dir_part = File.dirname(relative)
  group = dir_part == '.' ? root_group : ensure_groups(root_group, dir_part)
  ref = group.new_reference(relative, :group)
  target.resources_build_phase.add_file_reference(ref)
end

# -----------------------------------------------------------
# 3. 链接系统 Framework
# -----------------------------------------------------------
frameworks_group = main_group['Frameworks'] || main_group.new_group('Frameworks')

%w[SwiftUI Foundation Combine].each do |fw|
  ref = frameworks_group.new_reference("System/Library/Frameworks/#{fw}.framework", :sdk_root)
  target.frameworks_build_phase.add_file_reference(ref)
end

# -----------------------------------------------------------
# 4. 保存
# -----------------------------------------------------------
project.save
puts "✅ 已生成 #{APP_NAME}.xcodeproj"
puts "   Swift 文件: #{source_files.count} 个"
puts "   Plist 文件: #{plist_files.count} 个"
puts "   Asset 目录: #{asset_dirs.count} 个"
