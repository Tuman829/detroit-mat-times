require "rake/testtask"

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "mat_times"

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/*_test.rb"
  task.warning = false
end

namespace :test do
  desc "Run the JavaScript tests"
  task :js do
    sh "node --test 'test/js/*.test.js'"
  end
end

desc "Compile the site into _site/"
task :build do
  MatTimes::SiteBuilder.from_project.write(to: File.join(MatTimes::ROOT, "_site"))
end

desc "Build every theme into _site/themes/ to compare them locally"
task :themes do
  MatTimes::SiteBuilder.themes.each do |theme|
    MatTimes::SiteBuilder.from_project(theme: theme).write(to: File.join(MatTimes::ROOT, "_site/themes", theme))
  end
end

namespace :sheet do
  desc "Refresh data/sheet from the Google Sheet"
  task :pull do
    MatTimes::SheetPull.new(to: File.join(MatTimes::ROOT, "data/sheet")).call
  end
end

namespace :gyms do
  desc "Look up map pins for gyms that don't have one yet"
  task :locate do
    builder = MatTimes::SiteBuilder.from_project
    MatTimes::GymLocator.new(file: MatTimes::SiteBuilder::COORDINATES).call(builder.timetable.gyms)
  end
end

task default: %i[test test:js build]
