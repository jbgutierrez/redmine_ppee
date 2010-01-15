require 'application'
require 'rfpdf/fpdf'
require_dependency 'issues_controller'

module PPEE
  module IssuesControllerPatch

    def self.included(base)
      base.class_eval do
        include(InstanceMethods)
        alias_method_chain :new, :warnings
        alias_method_chain :edit, :warnings
      end
    end

    module InstanceMethods
      def new_with_warnings
        new_without_warnings
        flash[:message] = "No te olvides de anexar el documento de soporte si lo tienes"  if @issue.documento_soporte.blank?
      end

      def edit_with_warnings
        edit_without_warnings
        if request.post?
          flash[:message] = "En el estado en el que está debería tener un versión fijada"  if @issue.fixed_version.nil? and !@issue.fixed_version.estado_original?
        end
      end
    end

  end
end
