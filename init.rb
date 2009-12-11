require 'redmine'
require 'dispatcher'

#redmine patches
require 'issue_patch'

Dispatcher.to_prepare do
  Issue.send(:include, PPEE::IssuePatch)
end

Redmine::Plugin.register :redmine_ppee do
  name 'Redmine Ppee plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
end
