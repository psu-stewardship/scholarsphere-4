# frozen_string_literal: true

module Dashboard
  class WorksController < BaseController
    layout 'frontend'

    after_action :update_index, only: [:update]

    def edit
      @undecorated_work = Work.find(params[:id])
      authorize(@undecorated_work)
      initialize_forms
    end

    def update
      @undecorated_work = Work.find(params[:id])
      authorize(@undecorated_work)
      initialize_forms

      form = select_form_model

      if form.save
        redirect_to edit_dashboard_work_path(@undecorated_work), notice: t('.success')
      else
        render :edit
      end
    end

    private

      # @note Work indexing is largely handled via the WorkVersion and not the actual work. Placing a callback on the
      # Work could interfere with that process, so instead we reindex the work directly here in the controller.
      def update_index
        WorkIndexer.call(@undecorated_work, commit: true)
      end

      def initialize_forms
        @work = WorkDecorator.new(@undecorated_work)
        @work.attributes = work_params

        @embargo_form = EmbargoForm.new(work: @undecorated_work, params: embargo_params)
        @editors_form = EditorsForm.new(resource: @undecorated_work, user: current_user, params: editors_params)
      end

      def select_form_model
        if params[:embargo_form].present?
          @embargo_form
        elsif params[:editors_form].present?
          @editors_form
        else
          @work
        end
      end

      # Never trust parameters from the scary internet, only allow the white list through.
      def work_params
        params
          .fetch(:work, {})
          .permit(
            :visibility
          )
      end

      def embargo_params
        params
          .fetch(:embargo_form, {})
          .permit(
            :embargoed_until,
            :remove
          )
      end

      def editors_params
        params
          .fetch(:editors_form, {})
          .permit(
            edit_users: [],
            edit_groups: []
          )
      end
  end
end
