class window.ScorecardHistogram
  constructor: (id) ->
    id.find('.datetimepicker').datetimepicker(
      sideBySide: true,
      locale: 'ru',
    )

    id.find('select').chosen()

class window.ScrolledScorecardTable
  constructor: (id)->
    $(window).scroll ->
      more_rows_url = $('#infinite-scrolling ul li.next a').attr('href')
#      if more_rows_url && $(window).scrollTop() > $(document).height() - $(window).height() - 350 #350 => scrollbar not reach a footer
#        $('.pagination').fadeIn("slow");
#        $('.pagination').text("Fetching more data...")
#        $('.pagination').fadeOut("slow")

#        $.getScript(more_rows_url, success: (response,status)=>
#          window.scorecard_table = undefined
#          window.scorecard_table = new ScrolledScorecardTable(id)
#        )

      return
$(document).ready ->
  if window.location.pathname.match(/scorecard_histograms/)
    window.scorecard_histogram = new ScorecardHistogram($('#scorecard-histogram'))
    window.scrolled_scorecard_histogram = new ScrolledScorecardTable($('#scorecard-histogram'))

