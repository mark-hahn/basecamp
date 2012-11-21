# basecamp

A wrapper for the basecamp json api

The basecamp github project can be found [here](https://github.com/mark-hahn/basecamp).

## Features
 
- Supports new Basecamp json api (not old xml)
- Built-in oauth2 support
- Tools to link app to Basecamp account by visiting 37signals website
- Supports all api requests, GET, POST, and PUT
- Terminology, params, and command names match api documentation
- All data in/out are javascript objects
- Supports simultaneous multiple accounts

## Status:

Not ready for usage yet.  OAuth2 login and account connection works.  The framework to execute commands works but the command table only has a few commands so far.

*TODO* ...

- Complete command table
- Support express/connect for linking accounts callback
- Tests

## Installation

Will be installable via npm when it reaches alpha.

## Usage

The basecamp wrapper module interface follows the Basecamp api [documentation](https://github.com/37signals/bcx-api) closely.  Refer to the api document for help understanding the commands.  The wrapper module command constants follow the documentation headings (see the `project.req` method below).

Three classes are available.

### Client Class
  
    client = new basecamp.Client(client_id, client_secret, redirect_uri, userAgent);

Client represents your client application.

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
    
Account represents a Basecamp account that your user is linked to.

`client` is an instance of the `Client` class.

`accountId` is the Basecamp id for the account.  An array of all accounts with their ids is provided in the `userInfo` object returned by the `authNewCallback` callback (see above).  An example would be `userInfo.accounts[index].id`.

`refresh_token` is also taken from the `userInfo` object returned by the `authNewCallback` callback. It is available as `userInfo.refresh_token`.

The `callback` signature is `(error, account)`. `error` is a standard error param from a node callback and `account` is the instance of the class `Account` that has just been created.

The return value of this method should be ignored.  You might notice that this is unusual for a class constructor.

### Account Method req

    account.req(options, callback);

`req` is a method used to perform a request to a Basecamp account. This is rarely used compared to the `project.req` outlined below.

`options` specifies the request.  Available properties include ...

- `op` is the operation code that specifies the request command to use. It's values can be "get_projects", "get_projects_archived", and "create_project".  

- `data` is the data used to create a project in the "create_project" command. A sample value would be `{name: "This is my new project!", description: "It's going to run real smooth"}`.

If you are only using the `op` property then you can use that string value for the `options` param instead of an object. 
    
The `callback` signature is `(error, result)`.  `error` is a standard error param from a node callback. `result` is the object returned by the Bascamp api request (account.req).  The contents of `result` varies based on the command `options.op`.  See the Basecamp [documentation](https://github.com/37signals/bcx-api) for details.

### Project Class
  
    new basecamp.Project(account, projectId, callback);
 
Project represents a single project in a Bascamp account.

`account` is an instance of the `Account` class.

`projectId` is the Basecamp id for the project.  Usually you would obtain the project id by using the "get_projects" command (see above).

The `callback` signature is `(error, project)`. `error` is a standard error param from a node callback and `project` is the instance of the class `Project` that has just been created.

The return value of this method should be ignored.  You might notice that this is unusual for a class constructor.

### Project Method req

    project.req(options, callback);

Finally we get to the meat of the wrapper.  `req` is the method used to perform most of the requests to the Basecamp api.

`options` specifies the request.  Available properties include ...

- `op` is the operation code that specifies the request command to use. There are many possible values but you can figure them out from the api [documentation](https://github.com/37signals/bcx-api).  The operation code is the section header in the docs in lower case with an underscore separating words.  For example, the command described in the section "Get message" uses "get_message" as the command string.

- `data` is the data used in the body of POST and PUT requests.

If you are only using the `op` property then you can use that string value for the `options` param instead of an object. 

There will be more options required as all the commands are implemented.  For example the "get_message" command mentioned above will require the `options.messageId` value.

## Credits

Work on this project was done while on the job for [The Buddy Group](http://thebuddygroup.com).

Thanks goes out to 37signals for support on the Basecamp api forum.

## License

Standard MIT license.  See the `LICENSE` file.
