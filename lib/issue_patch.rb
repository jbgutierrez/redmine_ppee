require_dependency 'issue'

module PPEE
  module IssuePatch

    def self.included(base)
      base.class_eval do
        include InstanceMethods
        before_save :assign_to_current_user, :unless => proc { |issue| issue.status_id == CONST::ORIGINAL }
        before_save :fill_start_date, :unless => proc { |issue| issue.status_id == CONST::ORIGINAL }
        before_save :fill_due_date
        before_validation :refresh_done_ratio, :if => proc { |issue| issue.status_id_changed? & !issue.done_ratio_changed? }
        alias_method_chain :validate, :custom_validations
        alias_method_chain :after_initialize, :custom_values
      end
    end

    module InstanceMethods

      def after_initialize_with_custom_values
        after_initialize_without_custom_values
        self.description ||= CONST::DESCRIPTION_TEMPLATE
      end

      def validate_with_custom_validations
        validate_without_custom_validations
        validate_ratio_done_value
      end

      def documento_soporte
        @@id_documento_soporte ||= CustomField.find_by_name("Documento de soporte").id
        custom_field_values[@@id_documento_soporte].value
      end

      private

      def validate_ratio_done_value
        expected_range = CONST::EXPECTED_DONE_RATIO_RANGES[status_id]
        unless !expected_range || expected_range === self.done_ratio
          errors.add_to_base expected_range.class == Range ?
            "El porcentaje realizado debe estar entre #{expected_range.min} y #{expected_range.max}" :
            "El porcentaje realizado debe ser #{expected_range}"
        end
      end

      def refresh_done_ratio
        default_value = CONST::EXPECTED_DONE_RATIO_RANGES[status_id]
        default_value = default_value.min if default_value.class == Range
        self.done_ratio = default_value
      end

      def assign_to_current_user
        self.assigned_to ||= User.current
      end

      def fill_start_date
        self.start_date ||= Time.now
      end

      def fill_due_date
        if status_id == CONST::CERRADA
          self.due_date ||= Time.now
        else
          self.due_date = ''
        end
      end
    end

    module CONST
      # Estados de la incidencia
      ORIGINAL = 1
      ASIGNADA = 2
      EN_PRUEBAS = 3
      CERRADA = 5
      RECHAZADA = 6
      COMENTARIOS = 8

      # Pesos de avance de trabajo
      EXPECTED_DONE_RATIO_RANGES = { ORIGINAL => 0, ASIGNADA => 10..80, EN_PRUEBAS => 90, CERRADA => 100, RECHAZADA => 0 }

      # Plantilla por defecto para la descripcion de la incidencia
      DESCRIPTION_TEMPLATE =<<EOS
[completar descripción original]

*Descripción del cambio:*
[completar]

*Aspectos funcionales:*
[completar]

*Aspectos técnicos:*
[completar]

*Aspectos de configuración y parametrización:*
[completar]

*Pruebas:*
[completar]
EOS
    end
  end
end