postMessageHandler = (event)->
  if not event.origin.match(/^https:\/\/([\w\-]+\.)*bsvecosystem\.net/) then return
  try
    request = JSON.parse(event.data)
  catch
    return
  if request.type == "eha.dossierRequest"
    title = "BIRT"
    url = window.location.toString()
    species = GritsFilterCriteria.tokens.get().join(", ")
    start = GritsFilterCriteria.operatingDateRangeStart.get().toISOString().split("T")[0]
    end = GritsFilterCriteria.operatingDateRangeEnd.get().toISOString().split("T")[0]
    activeTable = $('.dataTableContent').find('.active').find('.table.dataTable')
    if activeTable.length
      dataUrl = 'data:text/csv;charset=utf-8;base64,' + activeTable.tableExport(
        type: 'csv'
        outputMode: 'base64'
      )
      if $(".seasonal-view.active").length == 0
        title = "Sightings of #{species} #{start} to #{end}"
      else
        toastr.error("CSV data is not available for the seasonal view.")
        return
      window.parent.postMessage(JSON.stringify({
        type: "eha.dossierTag"
        html: """<a href='#{dataUrl}'>Download Data CSV</a><br /><a target="_blank" href='#{url}'>Open BIRT</a>"""
        title: title
      }), event.origin)

window.addEventListener("message", postMessageHandler, false)
