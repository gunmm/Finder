require 'xcodeproj'

project_path = 'Finder.xcodeproj'
project = Xcodeproj::Project.open(project_path)

group = project.main_group.groups.find { |g| g.name == 'Finder' || g.path == 'Finder' }
if group.nil?
  puts "Finder group not found!"
  exit 1
end

# Check if file_ref already exists
existing = group.files.find { |f| f.path == 'InstructionsViewController.swift' }
if existing
  puts "File already in project"
  exit 0
end

file_ref = group.new_reference('InstructionsViewController.swift')
target = project.targets.first
target.source_build_phase.add_file_reference(file_ref, true)

project.save
puts "Added successfully"
