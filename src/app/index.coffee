app = require('derby').createApp(module)
    .use(require 'derby-ui-boot')
    .use(require '../../ui/index.coffee')

app.on 'model', (model) ->
    model.fn 'getRecordsStats', (records) ->
        console.log "getRecordsStats: #{records}"
        stats = {}
        if records?
            for rec in records when rec
                stats[rec.category] = if stats[rec.category] then stats[rec.category] + rec.amount else rec.amount
        # {name: k, summ: stats[k]} for k in Object.keys stats
        [k, parseInt(stats[k])] for k in Object.keys stats


# ROUTES #

# Derby routes are rendered on the client and the server
app.get '/', (page) ->
    page.render 'home'

app.get '/records', (page, model, params, next) ->
    # This value is set on the server in the `createUserId` middleware
    userId = model.get '_session.userId'

    # Create a scoped model, which sets the base path for all model methods
    user = model.at 'users.' + userId

    # Create a mongo query that gets the current user's items
    recordsQuery = model.query 'records', {userId}

    # Get the inital data and subscribe to any updates
    model.subscribe user, recordsQuery, (err) ->
        return next err if err

        # Create references that can be used in templates or controller methods
        model.ref '_page.user', user
        recordsQuery.ref '_page.records'
        user.increment 'visits'
        page.render 'records'
        console.log "render page"

app.enter '/records', (model) ->
    userId = model.get '_session.userId'
    user = model.at 'users.' + userId
    recordsQuery = model.query 'records', {userId}
    model.on 'all', '_page.records.**', (record, value) ->
        console.log "#{value} records: #{record}"
        if document?
            drawCharts model
    model.subscribe user, recordsQuery, (err) ->
        return next err if err
        console.log "app.enter '/records'"
        drawCharts(model)


# CONTROLLER FUNCTIONS #

drawCharts = (model) ->
    require '../lib/jquery.min.js'
    require 'highcharts-browserify'
    recordsStats = model.evaluate 'getRecordsStats', '_page.records'
    $('.highcharts-container').highcharts
        series: [{data: recordsStats}]
        chart:
            type: 'pie'
        tooltip:
            pointFormat: '<b>{point.percentage:.1f}%</b> - {point.y} руб.'
    console.log "drawCharts: #{recordsStats}"

app.ready (model) ->
    console.log "app.ready"

app.fn 'records.add', (e, el) ->
    newRecord = @model.del '_page.newRecord'
    return unless newRecord
    newRecord.userId = @model.get '_session.userId'
    newRecord.date = new Date()
    newRecord.amount = parseInt newRecord.amount
    @model.add 'records', newRecord, (err) =>
        return err if err?
        user = @model.at 'users.' + newRecord.userId
        categories = user.get 'categories'
        categories = [] if not categories?
        if categories.indexOf(newRecord.category) == -1
            categories.push newRecord.category
            user.set 'categories', categories.sort()

app.fn 'records.remove', (e) ->
    record = e.get ':record'
    @model.del 'records.' + record.id

app.fn 'records.drawCharts', (e) ->
    drawCharts @model
