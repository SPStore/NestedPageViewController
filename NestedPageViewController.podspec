Pod::Spec.new do |s|
  s.name             = 'NestedPageViewController'
  s.version          = '2.3.0'
  s.summary          = 'A nested page view controller for iOS with smooth scrolling coordination'
  s.description      = <<-DESC
                       NestedPageViewController provides a smooth nested scrolling experience
                       with header view, tab strip, and multiple child view controllers.
                       It coordinated scrolling between the header and child scroll views.
                       DESC

  s.homepage         = 'https://github.com/SPStore/NestedPageViewController'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '乐升平' => 'lesp163@163.com' }
  s.source           = { :git => 'https://github.com/SPStore/NestedPageViewController.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'Sources/NestedPageViewController/**/*'
  s.resource_bundles = {
    'NestedPageViewController.Privacy' => ['Sources/PrivacyInfo.xcprivacy']
  }
  
  s.frameworks = 'UIKit', 'Combine'
  s.requires_arc = true
end
