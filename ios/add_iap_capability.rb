require 'xcodeproj'

project_path = '/Users/apple/Desktop/gymguide_app/ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Update SystemCapabilities for all targets to include In-App Purchase
project.targets.each do |target|
  # Only add capabilities to application targets
  next unless target.symbol_type == :application

  target_attributes = project.root_object.attributes['TargetAttributes'] || {}
  
  target_id = target.uuid
  target_attributes[target_id] ||= {}
  target_attributes[target_id]['SystemCapabilities'] ||= {}
  target_attributes[target_id]['SystemCapabilities']['com.apple.InAppPurchase'] = { 'enabled' => '1' }
  
  project.root_object.attributes['TargetAttributes'] = target_attributes
end

project.save
puts "Successfully added In-App Purchase capability to Xcode project."
