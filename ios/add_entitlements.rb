require 'xcodeproj'

project_path = '/Users/apple/Desktop/gymguide_app/ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Ensure the Runner group exists
runner_group = project.main_group.find_subpath(File.join('Runner'), true)

# The path to the entitlements file relative to the group's directory
entitlements_path = 'Runner.entitlements'

# Check if the file reference already exists to avoid duplicates
file_ref = runner_group.files.find { |f| f.path == entitlements_path }
if file_ref.nil?
  file_ref = runner_group.new_file(entitlements_path)
  puts "Added Runner.entitlements to Xcode project."
else
  puts "Runner.entitlements already in Xcode project."
end

# Update build settings for all configurations
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  end
end

project.save
puts "Successfully updated CODE_SIGN_ENTITLEMENTS build setting."
