Pod::Spec.new do |s|
  s.name             = 'FieryCrucible'
  s.version          = '2.1.1'
  s.summary          = 'A minimalist type safe Swift dependency injection library.'
  s.description      = <<-DESC
A minimalist type safe Swift dependency injector factory. Where all true instances are forged.
                       DESC
  s.homepage         = 'https://github.com/jkolb/FieryCrucible'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'jkolb' => 'franticapparatus@gmail.com' }
  s.source           = { :git => 'https://github.com/jkolb/FieryCrucible.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/nabobnick'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.source_files     = 'Sources/*.swift'
end
