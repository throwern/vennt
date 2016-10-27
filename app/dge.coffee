
window.venn_settings ?= {}
key_column   = null
id_column    = null
fdrCol       = null
logFCcol     = null
info_columns = null
csv_file     = null
csv_data     = null
show_tour    = null
renderTo     = null
renderFormat = null
link         = null
link_column  = null
link_id_column=null

g_fdr_cutoff = 0.01
g_fc_cutoff  = 0

truncate = (text, limit, ending = '...') ->
  if text.length > limit
    return text.substring(0, limit - ending.length) + ending;  
  else
    return text
  
read_settings = () ->
    window.venn_settings ?= {}
    key_column   = venn_settings.key_column   || 'key'
    id_column    = venn_settings.id_column    || 'Feature'
    fdrCol       = venn_settings.fdr_column   || 'adj.P.Val'
    logFCcol     = venn_settings.logFC_column || 'logFC'
    info_columns = venn_settings.info_columns || [id_column]
    csv_file     = venn_settings.csv_file     || 'data.csv'
    csv_data     = venn_settings.csv_data
    show_tour    = if venn_settings.show_tour? then venn_settings.show_tour else true
    renderTo     = venn_settings.renderTo     || 'body'
    renderFormat = venn_settings.renderFormat || 'full'
    link         = venn_settings.link         || false
    link_column  = venn_settings.link_column  || false
    link_id_column  = venn_settings.link_id_column || false
    
is_signif = (item) ->
    !(item[fdrCol] > g_fdr_cutoff || Math.abs(item[logFCcol])<g_fc_cutoff)

setup_tabs = ->
    $('#overlaps .nav a').click (el) -> clickTab($(el.target).parent('li'))
    clickTab($('#overlaps li[data-target=venn]'))

clickTab = (li) ->
    return if $(li).hasClass('disabled')
    $('#overlaps .nav li').removeClass('active')
    li.addClass('active')
    id = li.attr('data-target')
    $('#overlaps #venn-table, #overlaps #venn').hide()
    $('#overlaps #'+id).show()

is_number = (n) ->
  !isNaN(parseFloat(n)) && isFinite(n)

class Overlaps
    constructor: (@gene_table, @data) ->
        @proportional = false

    get_selected: () ->
        sels = $('.selected')
        res = []
        for sel in sels
            name = $(sel).parent('li').attr('class')
            if $(sel).hasClass('total')
              res.push
                  name: name
                  typ: '' # 'Up/Down'
                  func: (row) -> is_signif(row)
            else if $(sel).hasClass('up')
              res.push
                  name: name
                  typ: 'Up : '
                  func: (row) -> is_signif(row) && row[logFCcol]>=0
            else if $(sel).hasClass('down')
              res.push
                  name: name
                  typ: 'Down : '
                  func: (row) -> is_signif(row) && row[logFCcol]<0
        res

    proportional_venn: (enabled) ->
        @_reset_venn()
        @proportional = enabled
        @update_selected()

    _reset_venn: () ->
        @last_names = null
        $('#overlaps svg').remove()

    _forRows: (set, cb) ->
        for id in @data.ids
            rowSet = @data.get_data_for_id(id)
            key = ""
            for s in set
                row = rowSet[s.name]
                key += if s.func(row) then "1" else "0"
            cb(key, rowSet)


    _int_to_key: (size, i) ->
        toBinary = (n,x) -> ("00000" +  x.toString(2)).substr(-n)
        reverseStr = (s) -> s.split('').reverse().join('')
        reverseStr(toBinary(size,i))

    _int_to_list: (size, i) ->
        s = @_int_to_key(size, i)
        res=[]
        for j in [0..s.length-1]
            res.push(j) if s[j]=='1'
        res

    _tick_or_cross: (x) ->
        "<i class='glyphicon glyphicon-#{if x then 'ok' else 'remove'}'></i>"

    _mk_venn_table: (set,counts) ->
        table = $('<table>')
        str = '<thead><tr>'
        for s in set
            str += "<th><div class='rotate'>#{s['typ']}#{s['name']}</div></th>"
        str += "<th>Number</tr></thead>"
        table.html(str)

        for k,v of counts
            continue if Number(k) == 0
            do (k,v) =>
                tr = $('<tr>')
                for x in k.split('')
                    tr.append("<td class='ticks'>#{@_tick_or_cross(x=='1')}")
                tr.append("<td class='total'><a href='#'>#{v}</a>")
                $(table).append(tr)

                $('tr a:last',table).click(() => @_secondary_table(k, set))

        $('#overlaps #venn-table').empty()
        $('#overlaps #venn-table').append(table)

    _mk_venn_diagram: (set, counts) ->
        if @proportional
            @_mk_venn_diagram_proportional(set, counts)
        else
            @_mk_venn_diagram_fixed(set, counts)

    _mk_venn_diagram_fixed: (set, counts) ->
        # Draw venn diagram
        $('#overlaps svg').remove()
        if set.length<=4
            n = set.length
            venn = {}
            # All numbers in the venn
            for i in [1 .. Math.pow(2,set.length)-1]
                do (i) =>
                    str = @_int_to_key(n,i)
                    venn[i] = {str: counts[str] || 0}
                    venn[i]['click'] = () => @_secondary_table(str, set)
            # Add the outer labels
            for s,i in set
                do (s,i) ->
                    venn[1<<i]['lbl']   = s['typ'] + s['name']
                    #venn[1<<i]['lblclick'] = () -> console.log(s['name'])
            draw_venn(n, '#overlaps #venn', venn)

    _mk_venn_diagram_proportional: (set, counts) ->
        # Draw an area proportional venn diagram
        n = set.length
        d = {}

        sets = []
        overlaps = []
        z = {}
        for i in [1 .. Math.pow(2,set.length)-1]
            do (i) =>
                str = @_int_to_key(n,i)
                lst = @_int_to_list(n,i)
                if lst.length>1
                    for j in lst
                        for k in lst
                            if j<k
                                s = "#{j},#{k}"
                                z[s] ||= {sets: [j,k], size: 0}
                                z[s].size += counts[str] || 0
                for j in lst
                    sets[j] ||= {label: set[j]['typ']+set[j]['name'], size: 0 }
                    sets[j].size += counts[str] || 0
                    #console.log lst,j,sets[j].size

        overlaps = d3.values(z)
        sets = venn.venn(sets, overlaps)
        names = set.map((s) -> s.name)
        if "#{names}" is "#{@last_names}"     # Poor mans array compare
            venn.updateD3Diagram(d3.select("#overlaps #venn"), sets)
        else
            $('#overlaps svg').remove()
            venn.drawD3Diagram(d3.select("#overlaps #venn"), sets, 750, 400)
        @last_names = names

    # Handle the selected counts.  Generate the venn table and diagram
    update_selected: () ->
        set = @get_selected()
        return if set.length==0

        counts={}
        @_forRows(set, (key) ->
            counts[key] ?= 0
            counts[key] += 1
        )

        @_mk_venn_table(set, counts)
        @_mk_venn_diagram(set, counts)

        # The non-proportional diagram can only do up to 4 classes
        $('#overlaps #venn #not-supported').toggle(!@proportional && set.length>4)

    _secondary_table: (k, set) ->
        rows = []
        @_forRows(set, (key, rowSet) ->
            if key==k
                row = []
                for s in set
                    if !row.id
                        row.id = rowSet[s.name][id_column]
                        info_columns.map((c) -> row[c] = rowSet[s.name][c])

                    row.push rowSet[s.name][logFCcol]
                rows.push(row)
        )

        desc = []
        cols = info_columns.map((c) => 
          format = (link && c==link_column) ? 'Link' : ''
          @gene_table.mk_column(c, c, format)
        )
        i=0
        for s in set
            signif = k[i]=='1'
            css = if signif then {} else {cssClass: 'nosig'}
            cols.push(@gene_table.mk_column(i, "logFC - #{s['name']}", 'logFC', css))
            desc.push(@_tick_or_cross(signif) + s['typ'] + s['name'])
            i+=1

        descStr = "<ul class='list-unstyled'>"+desc.map((s) -> "<li>"+s).join('')+"</ul>"
        @gene_table.set_name_and_desc("",descStr)

        @gene_table.set_data(rows, cols)

class LimitMsg
    constructor: () ->
        @count = {}
        @max = 10
    more: (tag) ->
        (!@count[tag]?) || (@count[tag]<@max)
    add: (tag) ->
        @count[tag] ||= 0
        @count[tag] += 1
    check_and_add: (tag) ->
        m = @more(tag)
        @add(tag)
        m

class Data
    constructor: (rows) ->
        @data = {}           # All genes, indexed gene ID column, then by condition KEY column

        limit_msg = new LimitMsg()
        ids = {}
        defined_columns = [key_column,id_column,fdrCol,logFCcol].concat(info_columns)
        all_keys = {}
        for r in rows
            continue if !r[key_column]?  # Skip blank rows
            if !r[id_column]
                if limit_msg.check_and_add(id_column)
                    log_error("No column (#{id_column}) in row : ",r)
                continue
            for c in defined_columns
                if !r[c]? && limit_msg.check_and_add(c)
                    log_error("Missing data for column : #{c}")

            d = (@data[r[id_column]] ?= {})
            r.id ?= r[id_column]   # Needed by slickgrid
            r.link_id ?= r[link_id_column]
            # Make number columns actual numbers
            for num_col in [fdrCol, logFCcol]
                if !is_number(r[num_col])
                    log_error("Not numeric '#{r[num_col]}' for row : #{r[id_column]}") if limit_msg.check_and_add(num_col)
                    r[num_col]=if num_col==fdrCol then 1.0 else NaN
                else
                    r[num_col]=parseFloat(r[num_col])

            key = r[key_column]
            all_keys[key] = 1
            d[key] = r

            ids[key] ?= {}
            if ids[key][r.id] && limit_msg.check_and_add('duplicate')
                log_error("Duplicate ID for #{key}, id=#{r.id}")
            ids[key][r.id]=1

        # Add missing any rows
        for id, d of @data
            for key,_ of all_keys
                if !d[key]?
                    if limit_msg.check_and_add('missing')
                        log_error("Missing ID for #{key}, id=#{id}")
                    # Fill in some defaults
                    d[key] = {id: id}
                    d[key][fdrCol] = 1.0
                    d[key][logFCcol] = NaN
                    # Find a row with info for the "info columns"
                    for c in info_columns
                        for k2,_ of all_keys
                            d[key][c] = d[k2][c] if d[k2]? && d[k2][c]?

        @ids = d3.keys(@data)
        @keys = d3.keys(@data[@ids[0]])

    get_data_for_key: (key) ->
        @ids.map((id) => @data[id][key])

    get_data_for_id: (id) ->
        @data[id]

    num_fdr: (key) ->
        num = 0; up=0; down=0
        for id,d of @data
            if is_signif(d[key])
                num+=1
                if (d[key][logFCcol]>0)
                    up++
                else
                    down++
        {'num': num, 'up': up, 'down': down}

class GeneTable
    constructor: (@opts) ->
        @_init_download_link()
        grid_options =
            enableCellNavigation: true
            enableColumnReorder: false
            multiColumnSort: false
            forceFitColumns: true
            enableTextSelectionOnCells: true
        @dataView = new Slick.Data.DataView()
        @grid = new Slick.Grid(@opts.elem, @dataView, [], grid_options)

        @dataView.onRowCountChanged.subscribe( (e, args) =>
            @grid.updateRowCount()
            @grid.render()
            @_update_info()
        )

        @dataView.onRowsChanged.subscribe( (e, args) =>
            @grid.invalidateRows(args.rows)
            @grid.render()
        )

        @grid.onSort.subscribe( (e,args) => @_sorter(args) )
        @grid.onViewportChanged.subscribe( (e,args) => @_update_info() )

        # Set up event callbacks
        if @opts.mouseover
            @grid.onMouseEnter.subscribe( (e,args) =>
                i = @grid.getCellFromEvent(e).row
                d = @dataView.getItem(i)
                @opts.mouseover(d)
            )
        if @opts.mouseout
            @grid.onMouseLeave.subscribe( (e,args) =>
                @opts.mouseout()
            )
        if @opts.dblclick
            @grid.onDblClick.subscribe( (e,args) =>
                @opts.dblclick(@grid.getDataItem(args.row))
            )

        @_setup_metadata_formatter((ret) => @_meta_formatter(ret))

    set_name_and_desc: (name,desc) ->
        $('#gene-list-name').html(name)
        $('#gene-list-desc').html(desc)

    _setup_metadata_formatter: (formatter) ->
        row_metadata = (old_metadata_provider) ->
            (row) ->
                item = this.getItem(row)
                ret = old_metadata_provider(row)

                formatter(item, ret)

        @dataView.getItemMetadata = row_metadata(@dataView.getItemMetadata)


    _meta_formatter: (item, ret) ->
        ret ?= {}
        ret.cssClasses ?= ''
        ret.cssClasses += if is_signif(item) then 'sig' else 'nosig'
        ret

    _get_formatter: (type, val, row) ->
        switch type
            when 'logFC'
                cl = if (val >= 0) then "pos" else "neg"
                "<div class='#{cl}'>#{val.toFixed(2)}</div>"
            when 'FDR'
                if val<0.01 then val.toExponential(2) else val.toFixed(2)
            when 'Link'
                '<a href="' + link + '/' + row['link_id'] + '" target="_blank">' + val + '</a>'
            else
                val

    _get_sort_func: (type, col) ->
        comparer = (x,y) -> (if x == y then 0 else (if x > y then 1 else -1))
        (r1,r2) ->
            r = 0
            x=r1[col]; y=r2[col]
            switch type
                when 'logFC'
                    comparer(Math.abs(x), Math.abs(y))
                when 'FDR'
                    comparer(x, y)
                else
                    comparer(x, y)

    mk_column: (fld, name, type, opts={}) ->
        o =
            id: fld
            field: fld
            name: name
            sortable: true
            formatter: (i,c,val,m,row) => @_get_formatter(type, val, row)
            sortFunc: @_get_sort_func(type, fld)
        if fld == 'Definition'
          o.width = 500
        $.extend(o, opts)

    _sorter: (args) ->
        if args.sortCol.sortFunc
            @dataView.sort(args.sortCol.sortFunc, args.sortAsc)
        else
            console.log "No sort function for",args.sortCol

    _update_info: () ->
        view = @grid.getViewport()
        btm = d3.min [view.bottom, @dataView.getLength()]
        $(@opts.elem_info).html("Showing #{view.top}..#{btm} of #{@dataView.getLength()}")

    refresh: () ->
        @grid.invalidate()

    set_data: (@data, @columns) ->
        @dataView.beginUpdate()
        @grid.setColumns([])
        @dataView.setItems(@data)
        @dataView.reSort()
        @dataView.endUpdate()
        @grid.setColumns(@columns)

    _init_download_link: () ->
        $('a#csv-download').on('click', (e) =>
            e.preventDefault()
            return if @data.length==0
            cols = @columns
            items = @data
            keys = cols.map((c) -> c.name)
            rows = items.map( (r) -> cols.map( (c) -> r[c.id] ) )
            window.open("data:text/csv,"+escape(d3.csv.format([keys].concat(rows))), "file.csv")
        )



class SelectorTable
    elem = "#files"
    constructor: (@data) ->
        @gene_table = new GeneTable({elem:'#gene-table', elem_info: '#gene-table-info'})
        @overlaps = new Overlaps(@gene_table, @data)
        @_mk_selector()
        @set_all_counts()
        @_initial_selection()

    _initial_selection: () ->
        @selected(@data.keys[0])
        $('.selectable.total')[0..2].addClass('selected')
        @overlaps.update_selected()

    _mk_selector: () ->
        span = (clazz) -> "<span class='selectable #{clazz}'></span>"
        for name in @data.keys
            do (name) =>
                li = $("<li class='#{name}'><a class='file' href='#'>#{truncate($.trim(name),25)}</a>"+
                       span("total")+span("up")+span("down"))
                $('a',li).click(() => @selected(name))
                $(elem).append(li)
        $('.selectable').click((el) => @_sel_span(el.target))

    proportional_venn: (enable) ->
        @overlaps.proportional_venn(enable)

    selected: (name) ->
        rows = @data.get_data_for_key(name)

        columns = info_columns.map((c) => 
          format = ''
          if link && c==link_column
            format = 'Link'
          @gene_table.mk_column(c, c, format)
        )
        columns.push(@gene_table.mk_column(logFCcol, logFCcol, 'logFC'),
                     @gene_table.mk_column(fdrCol, fdrCol, 'FDR'))
        @gene_table.set_data(rows, columns)
        @gene_table.set_name_and_desc("for '#{name}'", "")

    set_all_counts: () ->
        $('li',elem).each((i,e) => @set_counts(e))
        @gene_table.refresh()
        @overlaps.update_selected()

    set_counts: (li) ->
        name = $(li).attr('class')
        nums = @data.num_fdr(name)
        $(".total",li).text(nums['num'])
        $(".up",li).html(nums['up']+"&uarr;")
        $(".down",li).html(nums['down']+"&darr;")

    _sel_span: (item) ->
        if $(item).hasClass('selected')
            $(item).removeClass('selected')
        else
            $(item).siblings('span').removeClass('selected')
            $(item).addClass('selected')
        @overlaps.update_selected()
        false


class DGEVenn
    constructor: () ->
        read_settings()

        if csv_data
            # csv data is already in document
            @_data_ready(d3.csv.parse(venn_settings.csv_data))
        else
            # Fetch csv data using ajax
            d3.csv(csv_file, (rows) => @_data_ready(rows))

    _show_page: () ->
        if renderFormat=='simple'
            body = $(require("./templates/simple-body.hbs")())
            $(renderTo).append(body)
            $('vennt.container').show()
        else
            about = $(require("./templates/about.hbs")(vennt_version: vennt_version))
            body = $(require("./templates/body.hbs")())
            $(renderTo).append(body)
            $('#about-modal').replaceWith(about)
            $('#wrap > .container').show()
        $('#loading').hide()

        # Now the page exists!  Do some configuration
        setup_tabs()
        $("input.fdr-fld").value = g_fdr_cutoff
        $("a.log-link").click(() -> $('.log-list').toggle())

        setup_tour(show_tour)

    _data_ready: (rows) ->
        @_show_page()
        if !rows
            log_error("Unable to download csv file : '#{csv_file}'")
            return
        log_info("Downloaded data : #{rows.length} rows")
        data = new Data(rows)
        @selector = new SelectorTable(data)

        @_setup_sliders()
        $(".proportional input").change((e) => @selector.proportional_venn(e.target.checked))

        log_info("Ready!")

    _setup_sliders: () ->
        fdr_field = "input.fdr-fld"
        fdrStepValues = [0, 1e-5, 0.0001, 0.001, .01, .02, .03, .04, .05, 0.1, 1]
        @fdr_slider = new Slider("#fdrSlider", fdr_field,fdrStepValues, (v) => @set_fdr_cutoff(v))
        @fdr_slider.set_slider(g_fdr_cutoff)

        $(fdr_field).keyup((ev) =>
            el = ev.target
            v = Number($(el).val())
            if (isNaN(v) || v<0 || v>1)
                $(el).addClass('error')
            else
                $(el).removeClass('error')
            @set_fdr_cutoff(v)
        )

        fc_field = "input.fc-fld"
        fcStepValues = [0, 1, 2, 3, 4]
        @fc_slider = new Slider("#fcSlider", fc_field, fcStepValues, (v) => @set_fc_cutoff(v))
        @fc_slider.set_slider(g_fc_cutoff)

        $(fc_field).keyup((ev) =>
            el = ev.target
            v = Number($(el).val())
            if (isNaN(v) || v<0)
                $(el).addClass('error')
            else
                $(el).removeClass('error')
            @set_fc_cutoff(v)
        )

    set_fdr_cutoff: (v) ->
        g_fdr_cutoff = v
        @fdr_slider.set_slider(v)
        @selector.set_all_counts()

    set_fc_cutoff: (v) ->
        g_fc_cutoff = v
        @fc_slider.set_slider(v)
        @selector.set_all_counts()

$(document).ready(() -> new DGEVenn() )
