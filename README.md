This module makes it possible to integrate Elm with real-time storage services like [Firebase](http://firebase.com) or [Parse](http://parse.com).

The typical usage is:
1. Send cache update commands from your JavaScript glue code to a port of `Update`s.
1. Define a `Cache` which will store all remote objects.
1. Use `Reference`s in your model for cross-referencing objects stored in a cache.
1. Resolve the references from the cache when you need their values.
1. Collect the URLs of every reference in your model and send them to your JavaScript code to observe them.

For an example application, see: https://github.com/thSoft/RemoteModel