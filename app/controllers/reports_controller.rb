class ReportsController < ApplicationController

  # Creates a new report based on the DOIs stored in the session, and redirects to
  # display it.
  def generate
    dois = session[:dois]
    if dois.nil?
      
      # TODO: user-friendly error handling
      raise "No DOIs saved in session!"
    end

    @report = Report.new
    if !@report.save
      raise "Error saving report"
    end
    dois.each {|doi| @report.report_dois.create(:doi => doi)}
    
    if @report.save
      redirect_to :action => "show", :id => @report.id
    else
      
      # TODO
    end
  end
  
  
  def show
    @tab = :view_report
    @report = Report.find(params[:id])
    @docs = []
    
    # TODO: paging
    @report.report_dois.each do |report_doi|
      
      # TODO: same TODOs as HomeController.preview_list.  Cache results from solr.
      @docs << SolrRequest.get_article(report_doi.doi)
    end
  end
  
end