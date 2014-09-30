require 'csv'

class Report < ActiveRecord::Base
  # TODO: figure out what we want the default sort order to be.
  # doi is likely not a good solution.
  has_many :report_dois, -> { order(:sort_order) }

  # Creates a child ReportDoi object for each DOI passed in in the input array.
  # Sort order is determined by the position in the array.  This object must have
  # already been saved to the DB before this method is called.
  def add_all_dois(dois)

    # Since reports can have many DOIs, for performance we do a batch insert.
    # Active Record won't do this on its own.
    report_dois = dois.map.with_index do |doi, index|
      {
        doi: doi,
        sort_order: index
      }
    end
    self.report_dois.create(report_dois)

    # TEMP DISABLE, PRETTY BAD.
    # sql = "INSERT report_dois(doi, report_id, sort_order, created_at, updated_at) VALUES "
    # dois.each_with_index {|doi, i| sql << "('#{doi}', #{self.id}, #{i}, NOW(), NOW()), "}
    # sql[-2] = ";"
    # self.connection.execute(sql)
  end

  # Sets the @sorted_report_dates field.
  # Precondition: load_articles_from_solr has already been called.
  def sort_report_dates
    if @sorted_report_dates.nil?
      @sorted_report_dates = report_dois.collect{|report_doi| report_doi.solr.publication_date}
      @sorted_report_dates.sort!
    end
  end
  private :sort_report_dates


  # Returns the earliest publication date of any article in this report.
  # Precondition: load_articles_from_solr has already been called.
  def get_earliest_report_date
    sort_report_dates
    @sorted_report_dates[0]
  end


  # Returns the latest publication date of any article in this report.
  # Precondition: load_articles_from_solr has already been called.
  def get_latest_report_date
    sort_report_dates
    @sorted_report_dates[-1]
  end

  def to_csv(options = {})

    field = options[:field]

    if (field.nil?)

      alm_data = AlmRequest.get_data_for_articles(report_dois)
      solr_data = report_dois.map { |doi| SearchResult.from_cache(doi) }

      CSV.generate({ :force_quotes => true }) do | csv |
        title_row = [
            "DOI", "PMID", "Publication Date", "Title", "Authors", "Author Affiliations",
            ]
        title_row += AlmRequest.ALM_METRICS.values
        title_row += [
            "Journal", "Article Type", "Funding Statement", "Subject Areas", "Submission Date",
            "Acceptance Date", "Editors", "Article URL",
            ]
        csv << title_row

        report_dois.each do | report_doi |

          article_alm_data = alm_data[report_doi.doi]
          article_data = solr_data[report_doi.doi]

          # If the article was unpublished (rare), skip it.
          if !article_alm_data.nil? && !article_data.nil?
            row = [
                report_doi.doi, article_data["pmid"], article_data["publication_date"],

                # Some of the long free-form text fields can contain newlines; convert
                # these to spaces.
                article_data["title"].gsub(/\n/, ' '),
                build_delimited_csv_field(article_data["author_display"]),
                build_delimited_csv_field(article_data["affiliate"], "; "),
                ]
            AlmRequest.ALM_METRICS.keys.each {|metric| row.push(article_alm_data[metric])}
            row += [
                article_data["cross_published_journal_name"][0],
                article_data["article_type"],
                get_optional_field(article_data, "financial_disclosure").gsub(/\n/, ' '),
                Report.build_subject_string(article_data["subject"]),
                article_data["received_date"],
                article_data["accepted_date"],
                build_delimited_csv_field(article_data["editor_display"]),
                "http://dx.doi.org/#{report_doi.doi}"
                ]
            csv << row
          end
        end
      end

    elsif (field == "doi")
      CSV.generate({ :force_quotes => true}) do | csv |
        csv << ["DOI"]

        report_dois.each do | report_doi |
          csv << [report_doi.doi]
        end
      end
    end
  end


  # Returns a string suitable for inclusion in the CSV report for subject areas
  # of an article.  Only "leaf" or lowest-level categories are included.  The
  # input is the list of subjects as returned by solr.
  def self.build_subject_string(subject_list)
    if subject_list.nil?
      ""
    else

      # We sort on the leaf categories, just like ambra does.
      subject_list.collect{|subject| subject.split("/")[-1]}.sort.uniq.join(",")
    end
  end


  # Joins fields together for inclusion in a single CSV field.
  #
  # Params:
  #
  #   fields: list of fields to concatenate
  #   delimiter: delimiter used to join fields
  def build_delimited_csv_field(fields, delimiter=", ")
    result = fields.nil? ? "" : fields.join(delimiter)
    result.gsub(/\n/, ' ')
  end


  # Returns the given field from a solr data structure for an article, or the
  # empty string if the field does not exist.
  def get_optional_field(article_data, field_name)
    article_data[field_name].nil? ? "" : article_data[field_name]
  end

  def has_alm?
    report_dois.index{|r| r.alm.present? }.present?
  end
end
