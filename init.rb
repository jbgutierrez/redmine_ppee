require 'redmine'
require 'dispatcher'

#redmine patches
require 'issue_patch'
require 'issues_controller_patch'

Dispatcher.to_prepare do
  Issue.send(:include, PPEE::IssuePatch)
  IssuesController.send(:include, PPEE::IssuesControllerPatch)
end

Redmine::Plugin.register :redmine_ppee do
  name 'Redmine PPEE plugin'
  author 'Javier Blanco Gutiérrez'
  description 'Plugin de redmine con personalizaciones específicas para el proyecto PPEE'
  version '0.0.1'
  project_module :programas_especiales do
    permission :programas_especiales, :programas_especiales => :index
  end
end
