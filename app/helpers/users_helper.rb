#encoding: utf-8
module UsersHelper

  def stars_count user
    roles_hash =
      {
        'president'         => 9,
        'ceo'               => 8,
        'head_manager'      => 7,
        'director'          => 6,
        'executive'         => 5,
        'manager'           => 4,
        'regional_manager'  => 3,
        'teamlead'          => 2,
        'supervisor'        => 1,
      }
    roles_hash.default = 0
    roles_hash[user.role]
  end

  def space_for user
    shift = (2 - stars_count(user))
    shift = 0 if shift < 0
    ("&emsp;&emsp;" * shift).html_safe
  end

  def username_with_stars user
    stars = '<i class="icon-star"></i> ' * stars_count(user)
    user_title =
      if user == current_user
        content_tag(:strong, "#{user.name_or_email} (это я)")
      else
        user.name_or_email
      end
    stars.html_safe + user_title
  end

  def users_rerole_confirm(user)
    role = user.sv? ? t('helpers.users_helper.merchandiser') : t('helpers.users_helper.supervisor')
    %Q{Установить пользователю #{user.name} роль "#{role}"?}
  end

end
