#
# Be sure to run `pod lib lint MPModelKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MPModelKit'
  s.version          = '0.1.0'
  s.summary          = 'A lightweight toolkit that handle webservices and CoreData mapping'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
First, handles webservice connexions with `BackendService` and `APIRequest` implementations.
Then potentially maps the JSON into `Mappable` objects with `ResponseMapper` implementations.
Also, handles CoreData database with a `CoreDataManager` and some NSManagedObjectContext extensions.
                       DESC

  s.homepage         = 'https://github.com/Martin Prot/MPModelKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Martin Prot' => 'martinprot@gmail.com' }
  s.source           = { :git => 'https://github.com/martinprot/MPModelKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'MPModelKit/Classes/**/*'
  
  # s.resource_bundles = {
  #   'MPModelKit' => ['MPModelKit/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'PromiseKit', '~> 6.0'
  s.dependency 'SimpleKeychain'
end
