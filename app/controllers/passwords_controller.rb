class PasswordsController < Devise::PasswordsController

  def create
    email = resource_params[:email]
    resource_found = resource_class.find_by_email(email)
    if resource_found && resource_found.ldap_user?
      flash[:alert] = "Cannot reset password for LDAP user."
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name)) and return
    end

    self.resource = resource_class.send_reset_password_instructions(resource_params)
    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  end

  # After a user resets their password, prompt for 2FA code if enabled instead
  # of signing in automatically
  #
  # See http://git.io/vURrI
  def update
    super do |resource|
      # TODO (rspeicher): In Devise master (> 3.4.1), we can set
      # `Devise.sign_in_after_reset_password = false` and avoid this mess.
      if resource.errors.empty? && resource.try(:otp_required_for_login?)
        resource.unlock_access! if unlockable?(resource)

        # Since we are not signing this user in, we use the :updated_not_active
        # message which only contains "Your password was changed successfully."
        set_flash_message(:notice, :updated_not_active) if is_flashing_format?

        # Redirect to sign in so they can enter 2FA code
        respond_with(resource, location: new_session_path(resource)) and return
      end
    end
  end
end
