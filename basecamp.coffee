###
	basecamp: a wrapper for the basecamp json api
	todo:
		check for expired accesses
###

fs		= require 'fs'
url		= require 'url'
_		= require 'underscore'
request = require 'request'

opPaths = null

exports.Client = class Client

	constructor: (@client_id, @client_secret, @redirect_uri, @userAgent) ->

	getAuthNewUrl: (state) ->
		"https://launchpad.37signals.com/authorization/new" +
		"?type=" 				 + 'web_server' +
		"&client_id=" 			 + @client_id +
		"&redirect_uri=" 		 + encodeURIComponent(@redirect_uri) +
		(if state then "&state=" + encodeURIComponent(JSON.stringify state) else '')

	authNewCallback: (req, res, cb) ->
		query = url.parse(req.url, true).query
		if not query.code or query.error
			console.log 'basecamp: err in authorization/new callback: ' + req.url
			res.end()
			cb?()
			return
		@_getToken query, null, (err, userInfo, html) ->
			res.end html
			cb? err, userInfo

	_getToken: (cbQuery, refresh_token, cb) ->
		tokenUrl = "https://launchpad.37signals.com/authorization/token" +
					"?client_id=" 		+ @client_id +
					"&redirect_uri=" 	+ encodeURIComponent(@redirect_uri) +
					"&client_secret=" 	+ @client_secret
		form = {@client_id, @redirect_uri, @client_secret}
		if cbQuery
			tokenUrl += '&type=web_server&code=' + cbQuery.code
			_.extend form, code: cbQuery.code
			state = JSON.parse cbQuery.state ? '{}'
			href = state.href ? '/'
			html = """
				<html><head>
					<meta http-equiv="REFRESH" content="0;url=#{href}">
				</head><body></body></html> """
		else
			tokenUrl += '&type=refresh&refresh_token=' + refresh_token
			_.extend form, {refresh_token}
		request
			method: 'POST'
			uri:    tokenUrl
			form:   form
		, (error, response, bodyJSON) ->   # error authorization_expired

			if error or bodyJSON.indexOf('"error":') isnt -1
				console.log '\nbasecamp: token request error\n', {error, bodyJSON, cbQuery, refresh_token}
				cb? 'token request error'
				return
			tokenResp = JSON.parse bodyJSON
			request
				url: 'https://launchpad.37signals.com/authorization.json'
				headers: Authorization: 'Bearer ' + tokenResp.access_token
			, (error, response, bodyJSON) ->
				if error or bodyJSON.indexOf('error:') isnt -1
					msg =  '\nbasecamp: error from authorization request\n'
					console.log msg, {cbQuery, refresh_token, error, bodyJSON}
					cb? msg
					return
				userInfo = _.extend tokenResp, JSON.parse(bodyJSON), (if state then {state})
				cb? null, userInfo, html


exports.Account = class Account

	constructor: (@client, @accountId, refresh_token, cb) ->
		@account = null

		client._getToken null, refresh_token, (@err, @userInfo) =>
			if @err or not @userInfo.accounts
				console.log '\nbasecamp: _getToken error',
							@accountId, refresh_token, @err, @userInfo
				cb? '_getToken error'
				return
			for account in @userInfo.accounts
				if account.id is @accountId
					@account = account
					break
			if not @account
				@err = 'basecamp: account not found, ' +
						@userInfo.identity.email_address + ', ' + @accountId
				console.log '\nbasecamp ' + @err
				cb @err
				return
			if @account?.product isnt 'bcx'
				@err = 'basecamp: error, product ' + account?.product + ' not supported, ' +
							@userInfo.identity.email_address + ', ' + @accountId
				console.log '\nbasecamp ' + @err
				cb @err
				return
			cb null, @

	req: (op, options, cb) ->
		if not @account then cb 'basecamp: req error, no account'; return

		if not (path = opPaths[op])
			cb 'basecamp: req error, invalid opcode ' + op
			return

		{section, id, query, headers, body, stream, file} = options

		requestOpts =
			headers:
				'User-Agent':  @client.userAgent
				Authorization: 'Bearer ' + @userInfo.access_token

		if path[0] in ['P', 'D']
			if not body and not stream and not file
				cb 'basecamp: req body/stream/file missing', op, options
				return

			if body then requestOpts.json = body

			requestOpts.method = path.split('/')[0]
			path = path[requestOpts.method.length ..]

		urlReplacements = [
			['~primaryId~',  @primaryId]
			['~optionalId~', @primaryId]
			['~section~',     section  ]
			['~secondaryId~', id       ]
		]

		for replacement in urlReplacements when path.indexOf(replacement[0]) isnt -1
			if not replacement[1]
				if replacement[0] isnt '~optionalId~'
					cb 'option ' + replacement[0][1..-2] + ' missing'
					return
				path = path.replace '/' + replacement[0], ''
			else
				path = path.replace replacement[0], replacement[1]

		qStr = ''
		if query
			haveQM = (path.indexOf('?') isnt -1)
			for k,v of query
				qStr += (if haveQM then '&' else '?') + k + '=' + v
				haveQM = yes

		requestOpts.url = @account.href + path + qStr  # encodeURIComponent ?

		if headers then _.extend requestOpts.headers, headers

		reqCB = (error, response, bodyTxt) =>

#			console.log 'basecamp: req callback, err: ', error, ', resp type', (typeof bodyTxt)

			if typeof bodyTxt is 'string'
				try
					body = JSON.parse bodyTxt
				catch e
					error = bodyTxt
			else
				body = bodyTxt

			if error
				console.log '\nbasecamp: req error, bad response ' + op +
						   ' ' + @account.name, '\n\n', requestOpts, '\n\n', error
				cb error
				return

#            console.log '\nbasecamp: req response ' + op + ' ' +
#                        @userInfo.identity.email_address + ' ' + @account.name, body

			cb null, body

#        console.log '\n\nbasecamp: req url ' + requestOpts.url, {stream, file, requestOpts}

		if stream or file
			abortStream = no

			streamIt = ->
				reqst = stream.pipe request requestOpts

				reqst.on 'response', (resp) ->
					if resp.statusCode isnt 200
						reqCB 'bad stream status code ' + resp.statusCode + ', ' + requestOpts.url
						abortStream = yes

				reqst.on 'data', (resp) ->
					if not abortStream then reqCB null, null, resp.toString()

				reqst.on 'error', (resp) ->
					if not abortStream
						reqCB 'stream error ' + requestOpts.url + ', ' + JSON.stringify resp
						abortStream = yes

			if stream then streamIt(); return

			if not requestOpts.headers['Content-Length'] and
			   not requestOpts.headers['content-length']
				fs.stat file, (err, stats) ->
					if err
						reqCB 'fs.stat error ' + requestOpts.url + JSON.stringify err
						return

					_.extend requestOpts.headers, 'Content-Length': stats.size
					stream = fs.createReadStream file
					streamIt()
				return

			stream = fs.createReadStream file
			streamIt()

		else
			request requestOpts, reqCB


exports.Project = class Project
	constructor: (@account, @projectId) -> @primaryId = 'projects/' + @projectId
	req: (opts, cb) -> @account.req opts, cb


exports.Calendar = class Calendar
	constructor: (@account, @calendarId) -> @primaryId = 'calendars/' + @calendarId
	req: (opts, cb) -> @account.req opts, cb


exports.Person = class Person
	constructor: (@account, @personId) -> @primaryId = 'people/' + @personId
	req: (opts, cb) -> @account.req opts, cb


opPaths =
	# https://github.com/37signals/bcx-api/blob/master/sections/accesses.md
	get_accesses:				'/~primaryId~/accesses.json'
	grant_access:				'POST/~primaryId~/accesses.json'
	revoke_access:				'DELETE/~primaryId~/accesses/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/attachments.md
	create_attachment:			'POST/attachments.json'
	get_attachments:			'/~optionalId~/attachments.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/calendar_events.md
	get_calendar_events:		'/~primaryId~/calendar_events.json'
	get_calendar_events_past:	'/~primaryId~/calendar_events/past.json'
	get_calendar_event:			'/~primaryId~/calendar_events/~secondaryId~.json'
	create_calendar_event:		'POST/~primaryId~/calendar_events.json'
	update_calendar_event:		'PUT/~primaryId~/calendar_events/~secondaryId~.json'
	delete_calendar_event:		'DELETE/~primaryId~/calendar_events/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/calendars.md
	get_calendars:				'/calendars.json'
	get_calendar:				'/~primaryId~.json'
	create_calendar:			'POST/calendars.json'
	update_calendar:			'PUT/~primaryId~.json'
	delete_calendar:			'DELETE/~primaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/comments.md
	create_comment:				'POST/~primaryId~/~section~/~secondaryId~/comments.json'
	delete_comment:				'DELETE/~primaryId~/comments/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/documents.md
	get_documents:				'/~optionalId~/documents.json'
	get_document:				'/~primaryId~/documents/~secondaryId~.json'
	create_document:			'POST/~primaryId~/documents.json'
	update_document:			'PUT/~primaryId~/documents/~secondaryId~.json'
	delete_document:			'DELETE/~primaryId~/documents/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/events.md
	get_global_events:			'/events.json'
	get_project_events:			'/~primaryId~/events.json'
	get_person_events:			'/~primaryId~/events.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/messages.md
	get_message:				'/~primaryId~/messages/~messageId~.json'
	create_message:				'POST/~primaryId~/messages.json'
	update_message:				'PUT/~primaryId~/messages/~secondaryId~.json'
	delete_message:				'DELETE/~primaryId~/messages/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/people.md
	get_people:					'/people.json'
	get_person:					'/~primaryId~.json'
	get_person_me:				'/people/me.json'
	delete_person:				'DELETE/~primaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/projects.md
	get_projects: 				'/projects.json'
	get_projects_archived: 		'/projects/archived.json'
	get_project:				'/~primaryId~.json'
	create_project: 			'POST/projects.json'
	update_project:				'PUT/~primaryId~.json'
	delete_project:				'DELETE/~primaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/todolists.md
	get_todolists:				'/~primaryId~/todolists.json'
	get_todolists_completed:	'/~primaryId~/todolists/completed.json'
	get_todolists_all:			'/todolists.json'
	get_todolists_all_completed: 		'/todolists/completed.json'
	get_todolists_with_assigned_todos: 	'/~primaryId~/assigned_todos.json'
	get_todolist:				'/~primaryId~/todolists/~secondaryId~.json'
	create_todolist: 			'POST/~primaryId~/todolists.json'
	update_todolist:			'PUT/~primaryId~/todolists/~secondaryId~.json'
	delete_todolist:			'DELETE/~primaryId~/todolists/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/todos.md
	get_todo:					'/~primaryId~/todos/~secondaryId~.json'
	create_todo: 				'POST/~primaryId~/todos.json'
	update_todo:				'PUT/~primaryId~/todos/~secondaryId~.json'
	delete_todo:				'DELETE/~primaryId~/todos/~secondaryId~.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/topics.md
	get_topics:					'/~primaryId~/topics.json'
	get_topics_all:				'/topics.json'

	# https://github.com/37signals/bcx-api/blob/master/sections/uploads.md
	create_uploads:				'POST/~primaryId~/uploads.json'
	get_upload:					'~primaryId~/uploads/~secondaryId~.json'
