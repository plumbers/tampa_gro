require_relative '../services/facades/web_api/admin/photo_exports/filters'

class Photo < ApplicationRecord
  include ::Facades::WebApi::Admin::PhotoExports::Filters

  alias_attribute :visit_id, :checkin_id

  COMMON_IMAGE_OPTIONS =
    { styles:
      {
        original:
          {
            geometry: '10000x10000>',
            convert_options: '-auto-orient'
          },
        large_square: '200x200#'
      }
    }

  IMAGE_CONTENT_VALIDATOR =
    {
      content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/,
      message: I18n.t('models.photo.unsupported_type_file')
    }

  CHECKIN_STARTED_DATE     = "(checkins.completed_at AT TIME ZONE 'UTC' AT TIME ZONE checkins.timezone)"

  has_attached_file :image,     COMMON_IMAGE_OPTIONS.merge(default_url: "/missing_images/:style/missing.png")
  has_attached_file :aws_image, COMMON_IMAGE_OPTIONS.merge(Rails.configuration.aws_options)
  process_in_background :image, queue: :paperclip

  belongs_to :question
  belongs_to :checkin, counter_cache: true
  belongs_to :report, counter_cache: true

  validates :checkin_id, presence: true
  validates :image, presence: true, if: lambda{|i| i.aws_image.blank?}
  validates :aws_image, presence: true, if: lambda{|i| i.image.blank?}

  validates_attachment_content_type :image, IMAGE_CONTENT_VALIDATOR
  validates_attachment_content_type :aws_image, IMAGE_CONTENT_VALIDATOR

  def queue_upload_to_s3
    Rails.configuration.aws_uploader.perform_async(self.id, self.checkin_id)
  end

  def aws_path
    (aws_image.exists? ? aws_image : image).path&.gsub(/\?.*|\A\/|.*\/system\//,'')
  end

  # добавить следующие функции:
  # 1) Фильтрация по опросникам;
  # 1) Фильтрация по вопросу опросника;
  # 5) Фильтрация по набору ExID точек;
  # 6) Фильтрация по типу торговой точки;
  # ***) Фильтрация по jsonb полю data из торговой точки - например, client_type
  #     "region": "Золотое Кольцо",
  #     "channel": "Современная Торговля",
  #     "iformat": "Золотое Кольцо Атак S1 Владимир",
  #     "territory": "Владимир",
  #     "network_name": "Ашан",
  #     "territory_type": "Первичные продажи",
  #     "client_category": "Ключевые клиенты"

  # 4) В названии ZIP файла добавить юзера, по которому создаётся выгрузка;

  # --- 2) Добавление нескольких условий для выгрузки -
  #         например:
  #         выгрузить архив фото по опроснику +
  #         в этом же запросе по нескольким вопросам другого опросника; (отложено)

  # 8) Фильтрация по заголовку экрана

  # USE from TO component
  # 9) Опциональное правило формирования подкаталогов архива:
  #     -  по датам
  #     -  компания
  #     -  вывеска
  #     -  тип ТТ
  # 10) Опциональное правило формирования имя файлов фоток (подрезать при макс длине кроме id фотки и даты):
  #   - id точки, вывеска, юр. название, тип точки, опросник, название вопроса, дата, id фотки

end
