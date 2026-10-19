Pod::Spec.new do |s|
  s.name             = "CareJobs"
  s.version          = "1.0.0"
  s.summary          = "Swift client for the CareJobs.Now healthcare jobs API: US healthcare jobs, posted pay, employers and states."
  s.description      = <<-DESC
    CareJobs is an async/await Swift client for the free CareJobs.Now API. Search open US healthcare jobs
    (nurses, CNAs, medical assistants, therapists, techs, pharmacy, physicians and more) read every day from
    hospitals' and care employers' own career sites, with the pay each employer posts; read posted pay by kind
    of job, the job market, jobs by state and employers. Codable results, no dependencies, no API key.
  DESC
  s.homepage         = "https://github.com/yumaheymans/carejobs-swift"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "CareJobs.Now" => "hello@carejobs.now" }
  s.source           = { :git => "https://github.com/yumaheymans/carejobs-swift.git", :tag => s.version.to_s }
  s.documentation_url = "https://carejobs.now/data"

  s.ios.deployment_target     = "15.0"
  s.osx.deployment_target     = "12.0"
  s.swift_versions   = ["5.9"]

  s.source_files     = "Sources/CareJobs/**/*.swift"
  s.frameworks       = "Foundation"
end
