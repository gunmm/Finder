require 'xcodeproj'

project_path = '/Users/minzhe/AIProject/Finder/Finder.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Set for Project level
project.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

# Set for each Target
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end
end

project.save
puts "Successfully disabled User Script Sandboxing in Finder.xcodeproj"
