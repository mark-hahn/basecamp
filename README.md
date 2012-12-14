# Basecamp

A nodejs module that wraps the Basecamp JSON api.

The Basecamp github project can be found [here](https://github.com/mark-hahn/basecamp).


## Features

- Supports new Basecamp JSON api (not old xml)
- Built-in oauth2 support
- Tools to link app to Basecamp account by visiting 37signals website
- Supports all 57 api requests (GET, POST, and PUT)
- Terminology, params, and command ops match api documentation
- Data can be objects, streams, or files
- Supports simultaneous multiple accounts


## Status Alpha

It is complete and currently usable, but it has not been used in production yet and there are no unit tests. Many commands (those relating to accounts, projects, messages, and comments) have been verified to work ...

- get_projects
- get_projects_archived
- create_project
- create_attachment
- get_project
- get_accesses
- get_topics
- get_message
- create_message
- create_comment

The rest of the commands are expected to work. A command table was translated directly from the API docs and the commands that have been verified to work use that table.

*TODO* ...

- Tests
- Add coding examples to this readme
- Convenience functions for common commands
- Support express/connect for linking accounts callback

I could use some help. Tests will be hard since we can't easily mock the Basecamp api. I don't know express so someone else is going to have to add that.


## Installation

npm install basecamp


## Usage

The Basecamp wrapper module interface follows the Basecamp api [documentation](https://github.com/37signals/bcx-api) closely.  Refer to the api document for help understanding the commands.


### Client Class

    client = new Basecamp.Client(client_id, client_secret, redirect_uri, userAgent);

Client represents your client application. This usually only has one instance (singleton).

`client_id` is the id given to you when registering your Basecamp application.

`client_secret` is the secret given to you when registering your Basecamp application.

`redirect_uri` is a return address to your app server. You use this to send your user to the Basecamp account to link their Basecamp acount to your application. It must *exactly* match what you specified during app registration.

`userAgent` is sent on every request.  It is just a comment like "Your name (yourWebsite.com)". It is not connected to the registration of your app.

### Client Method authNewUrl

    authNewUrl = client.getAuthNewUrl(state);

Returns the url that your app's web page should use when taking the user to the Basecamp website to link their account with your app. Since this module runs in the server the url will need to be sent to the client. Usually this would be through an ajax request but could be sent with the html page in some situations.

*Hint:* This url could actually be a constant string in your web page.  You would have to figure out that URL yourself.  However, using the `getAuthNewUrl` method will guarantee the url is correct in future releases.

`state` is an arbitrary javascript object that will be serialized and added to this url.  It will be returned to you when the Basecamp server issues the callback request to your server (see the `authNewCallback` method below).  If the object has the property `href`, as in `state.href`, then the `authNewCallback` method below will redirect the user to this `href`.  Usually you would provide a user id in the state object so you know what user is responsible for the Basecamp callback.

### Client Method authNewCallback

    client.authNewCallback(request, response, callback);

Your app server should route an incoming request for the `redirect_uri` specified above to this method.  The `request` and `response` params are the ones supplied by the node `http.createServer` callback.

The `callback` signature is `(error, userInfo)`.  `error` is a standard error param from a node callback.

`userInfo` is an object that you should store for future use.  Usually this would be stored in a db record for the user.  Some of it's data will be needed for future method calls.

If you specifed a `state` param in the `getAuthNewUrl` method, then the state object will be available as `userInfo.state`.

The userinfo also contains a Basecamp user object in `userInfo.identity` and an array of account objects  in `userInfo.accounts`. They represent all accounts the user has access to.  Usually you would ask the user what account they want to interact with by presenting them a list of these accounts to choose from.

The return value of this method should be ignored.

### Account Class

    new basecamp.Account(client, accountId, refresh_token, callback);

Account represents a Basecamp account.  Multiple instances for different accounts may exist at once.

`client` is an instance of the `Client` class.

`accountId` is the Basecamp id for the account.  An array of all accounts with their ids is provided in the `userInfo` object returned by the `authNewCallback` callback (see above).  An example of accountId would be `userInfo.accounts[index].id`.

`refresh_token` is also taken from the `userInfo` object returned by the `authNewCallback` callback. It is available as `userInfo.refresh_token`.

The `callback` signature is `(error, account)`. `error` is a standard error param from a node callback and `account` is the instance of the class `Account` that has just been created.

The return value of this method should be ignored.  You might notice that this is unusual for a class constructor.

There is only one method, `req`.  It is the same method for Account, Project, Calendar, and Person classes and is documented in the "req method" section below.

The valid commands (ops) for an Account are listed here.  They are in the order they appear in the api docs.

[attachments](https://github.com/37signals/bcx-api/blob/master/sections/attachments.md)

- get_attachments
- create_attachment

[calendars](https://github.com/37signals/bcx-api/blob/master/sections/calendars.md)

- get_calendars
- create_calendar

[documents](https://github.com/37signals/bcx-api/blob/master/sections/documents.md)

- get_documents

[events](https://github.com/37signals/bcx-api/blob/master/sections/events.md)

- get_global_events

[people](https://github.com/37signals/bcx-api/blob/master/sections/people.md)

- get_people
- get_person_me

[projects](https://github.com/37signals/bcx-api/blob/master/sections/projects.md)

- get_projects
- get_projects_archived
- create_project

[todolists](https://github.com/37signals/bcx-api/blob/master/sections/todolists.md)

- get_todolists_all
- get_todolists_all_completed

[topics](https://github.com/37signals/bcx-api/blob/master/sections/topics.md)

- get_topics_all


### Project Class

    new basecamp.Project(account, projectId);

Project represents a single project in a Basecamp account.

`account` is an instance of the `Account` class.

`projectId` is the Basecamp id for the project.  Usually you would obtain the project id by using the "get_projects" command.

There is only one method, `req`.  It is the same method for Account, Project, Calendar, and Person classes and is documented in the "req method" section below.

Valid commands (ops) for a Project are listed here.  They are in the order they appear in the api docs. Note that all Account commands can also be used on Projects.

[accesses](https://github.com/37signals/bcx-api/blob/master/sections/accesses.md)

- get_accesses
- grant_access
- revoke_access

[attachments](https://github.com/37signals/bcx-api/blob/master/sections/attachments.md)

- get_attachments

[calendar events](https://github.com/37signals/bcx-api/blob/master/sections/calendar_events.md)

- get_calendar_events
- get_calendar_events_past
- get_calendar_event
- create_calendar_event
- update_calendar_event
- delete_calendar_event

[comments](https://github.com/37signals/bcx-api/blob/master/sections/comments.md)

- create_comment
- delete_comment

[documents](https://github.com/37signals/bcx-api/blob/master/sections/documents.md)

- get_documents
- get_document
- create_document
- update_document
- delete_document

[events](https://github.com/37signals/bcx-api/blob/master/sections/events.md)

- get_project_events

[messages](https://github.com/37signals/bcx-api/blob/master/sections/messages.md)

- get_message
- create_message
- update_message
- delete_message

[projects](https://github.com/37signals/bcx-api/blob/master/sections/projects.md)

- get_project
- update_project
- delete_project

[todolists](https://github.com/37signals/bcx-api/blob/master/sections/todolists.md)

- get_todolists
- get_todolists_completed
- get_todolist
- create_todolist
- update_todolist
- delete_todolist

[todos](https://github.com/37signals/bcx-api/blob/master/sections/todos.md)

- get_todo
- create_todo
- update_todo
- delete_todo

[topics](https://github.com/37signals/bcx-api/blob/master/sections/topics.md)

- get_topics

[uploads](https://github.com/37signals/bcx-api/blob/master/sections/uploads.md)

- create_uploads
- get_upload


### Calendar Class

    new basecamp.Calendar(account, calendarId);

Calendar represents a single calendar in a Basecamp account.

`account` is an instance of the `Account` class.

`calendarId` is the Basecamp id for the calendar.  Usually you would obtain the calendar id by using the "get_calendars" command.

There is only one method, `req`.  It is the same method for Account, Project, Calendar, and Person classes and is documented in the "req method" section below.

Valid commands (ops) for a Calendar are listed here.  They are in the order they appear in the api docs. Note that all Account commands can also be used on Calendars.

[accesses](https://github.com/37signals/bcx-api/blob/master/sections/accesses.md)

- get_accesses
- grant_access
- revoke_access

[calendar events](https://github.com/37signals/bcx-api/blob/master/sections/calendar_events.md)

- get_calendar_events
- get_calendar_events_past
- get_calendar_event
- create_calendar_event
- update_calendar_event
- delete_calendar_event

[calendars](https://github.com/37signals/bcx-api/blob/master/sections/calendars.md)

- get_calendar
- update_calendar
- delete_calendar


### Person Class

    new basecamp.Person(account, personId);

Person represents a single person in a Basecamp account.

`account` is an instance of the `Account` class.

`personId` is the Basecamp id for the person.  Usually you would obtain the person id by using the "get_people" command.

There is only one method, `req`.  It is the same method for Account, Project, Calendar, and Person classes and is documented in the "req method" section below.

Valid commands (ops) for a Person are listed here.  They are in the order they appear in the api docs. Note that all Account commands can also be used on Person.

[events](https://github.com/37signals/bcx-api/blob/master/sections/events.md)

- get_person_events

[people](https://github.com/37signals/bcx-api/blob/master/sections/people.md)

- get_person
- delete_person

[todolists](https://github.com/37signals/bcx-api/blob/master/sections/todolists.md)

- get_todolists_with_assigned_todos


### req method for the classes Account, Project, Calendar, and Person

    account.req(op, options, callback);
    project.req(op, options, callback);
    calendar.req(op, options, callback);
    person.req(op, options, callback);

`req` is the method used to perform the requests to the Basecamp api.

`op` is a string that specifies the API request to use. The values are listed in the Account, Project, Calendar, and Person classes above.

`options` specifies request parameters.  Available options include ...

- `id` is a Basecamp id string. This is required for commands like get_message that refer to one specific item.

- `section` is a string that is only used in the create_comment command.  It can be "messages", "calendar_events", "uploads", or "todos".

- `query` is an optional object that will be added to the url. For example, in the `get_topics` command you will need to specify a page when there are 50 or more topics.  The query option might look like `{page:2}`.  This would create a url like `/projects/1/topics.json?page=2`.

- `headers` is a normal headers object, such as {'Content-Length': 12453}. Any value here takes precedence over any values generated automatically.

- `data` is a data object used for the request body in POST/PUT commands. Note that the Content-Type is set to 'application/json' and the Content-Length is automatically provided. Either can be overriden with the `headers` option.

- `stream` also provides data as in the `data` option, but it is a stream instead of an object. Both Content-Type and Content-Length will usually be needed in the headers option.

- `file` is a path to a file. When present the contents of the file are sent as the body.  If the Content-Length header is not set it will be set for you.  The Content-Type is not set and will usually need to be provided.

The `callback` signature is `(error, result)`.  `error` is a standard error param from a node callback. `result` is a javascript object with the api request results.  The contents of `result` vary based on the command.  See the Basecamp [documentation](https://github.com/37signals/bcx-api) for details. Note that some commands require multiple requests (see query option above) when more than 50 items are returned.


## Credits

Work on this project was done while on the job for [The Buddy Group](http://thebuddygroup.com).

Thanks goes out to 37signals for support on the Basecamp api forum.

## License

Standard MIT license.  See the `LICENSE` file.
