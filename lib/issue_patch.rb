require_dependency 'issue'

module PPEE
  module IssuePatch

    def self.included(base)
      base.class_eval do
        include InstanceMethods

        def self.filter_by_project(options)
          clause, method = options.keys.first, options.values.first.to_s
          condition = "Proc.new { |issue| #{clause == :if ? '' : '!' }issue.ppee_module_enabled? && issue.#{method} }"
          { clause => eval(condition) }
        end

        validates_presence_of :start_date,       filter_by_project(:unless => :is_original?)
        validates_presence_of :fixed_version_id, filter_by_project(:unless => :is_original?)
        validates_presence_of :due_date,         filter_by_project(:if => :is_closed?)
        before_validation :ensure_assigned_to,   filter_by_project(:if => :is_leaving_original?)
        before_validation :refresh_start_date,   filter_by_project(:if => :is_leaving_original?)
        before_validation :refresh_due_date,     filter_by_project(:if => :is_entering_closed?)
        before_validation :refresh_done_ratio,   filter_by_project(:if => :status_id_changed?)
        validate :validate_ratio_done_value,     :if => :ppee_module_enabled?
        alias_method_chain :after_initialize, :custom_values
      end
    end

    module InstanceMethods

      def ppee_module_enabled?
        self.project.module_enabled?(:programas_especiales)
      end

      def documento_soporte
        @@id_documento_soporte ||= CustomField.find_by_name("Documento de soporte").id
        custom_field_values[@@id_documento_soporte].value rescue ""
      end

      def is_leaving_original?
        status_id_changed? && status_id_was == CONST::ORIGINAL
      end

      def is_entering_closed?
        status_id_changed? && status_id == CONST::CERRADA 
      end

      def is_closed?
        status_id == CONST::CERRADA
      end

      def is_original?
        status_id == CONST::ORIGINAL
      end

      private

      def after_initialize_with_custom_values
        after_initialize_without_custom_values
        # return unless self.ppee_module_enabled?
        self.description ||= CONST::DESCRIPTION_TEMPLATE
      end

      def validate_ratio_done_value
        expected_range = CONST::EXPECTED_DONE_RATIO_RANGES[status_id]
        unless !expected_range || expected_range === done_ratio
          errors.add_to_base expected_range.class == Range ?
            "El porcentaje realizado debe estar entre #{expected_range.min} y #{expected_range.max}" :
            "El porcentaje realizado debe ser #{expected_range}"
        end
      end

      def refresh_done_ratio
        return if done_ratio_changed? && !done_ratio.blank?
        default_value = CONST::EXPECTED_DONE_RATIO_RANGES[status_id]
        default_value = default_value.min if default_value.class == Range
        self.done_ratio = default_value
      end

      def refresh_due_date
        return if due_date_changed? && !due_date.blank?
        self.due_date = Time.now.to_s(:db)
      end

      def refresh_start_date
        return if start_date_changed? && !start_date.blank?
        self.start_date = Time.now.to_s(:db)
        self.due_date   = nil
      end

      def ensure_assigned_to
        self.assigned_to ||= User.current
      end

    end

    module CONST
      # Estados de la incidencia
      ORIGINAL    = 1
      ACEPTADA    = 9
      ASIGNADA    = 2
      EN_PRUEBAS  = 3
      CERRADA     = 5
      RECHAZADA   = 6
      COMENTARIOS = 8

      # Pesos de avance de trabajo
      EXPECTED_DONE_RATIO_RANGES = { ORIGINAL => 0, ACEPTADA => 0, ASIGNADA => 10..80, EN_PRUEBAS => 90, CERRADA => 100, RECHAZADA => 0, COMENTARIOS => 0..100 }

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
