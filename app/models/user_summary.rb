class UserSummary
  BASE_SUMMARY = { completed: 0, total: 0, verified: 0 }.freeze

  def initialize(user)
    @user = user
  end

  def for_user
    @for_user ||= summary_data.map do |category|
      typecast_results_for(category)
    end
  end

  def for_category(category)
    summary = for_user.find do |data|
      category.handle == data[:handle]
    end

    summary.presence || initialized_summary(category)
  end

  def for_course(course)
    for_user.each_with_object(BASE_SUMMARY.merge({})) do |c, hash|
      next unless course.id == c[:course_id]

      hash[:completed]  += c[:total_completed]
      hash[:total]      += c[:total_skills]
      hash[:verified]   += c[:total_verified]

      hash[:completed_percent] = completed_percent(hash)
    end
  end

  private

  def completed_percent(hash)
    ((hash[:completed] / hash[:total]) * 100).ceil
  end

  def initialized_summary(category)
    { total_skills: category.skills.count, total_completed: 0, total_verified: 0 }
  end

  def summary_data
    connection.execute(summary_query)
  end

  def summary_query
    "select e.course_id, c.id, c.name, c.handle, count(*) total_skills,
      count(p.created_at) total_completed, count(p.verified_on) total_verified
    from enrollments e join categories c on c.course_id = e.course_id
      join skills s on s.category_id = c.id
      left join completions p on p.skill_id = s.id and p.user_id = #{@user.id}
    where e.user_id = #{@user.id} and c.hidden = 'f'
    group by e.course_id, c.id, c.handle, sort_order order by sort_order"
  end

  INTEGER_FIELDS = [:id, :course_id, :total_skills,
                    :total_completed, :total_verified].freeze

  def typecast_results_for(category)
    category.symbolize_keys!.tap do |hash|
      INTEGER_FIELDS.each { |field| hash[field] = hash[field].to_i }
    end
  end

  def connection
    ActiveRecord::Base.connection
  end
end
