public: yes
tags: [pyramid, gevent]
summary: |
    An introduction to using gevent with the Pyramid web framework to
    seemlessly support long polling in a WSGI application.

TicTacToe and Long Polling with Pyramid
=======================================

Long-polling in Python has always been complicated by the fact that it tends
to require an asynchronous web server. It's unrealistic to support thousands
(or event tens) of active connections given Python's threading issues
(the GIL, OS-level threads). There are several asynchronous solutions in
Python including
`Tornado <http://www.tornadoweb.org/>`__,
`Twisted <http://twistedmatrix.com/trac/>`__,
and `gevent <http://www.gevent.org/>`__.

Both Tornado and Twisted force you to write code in callbacks to avoid
blocking during long-running operations like I/O. Unfortunately this requires
your whole application to be written differently from how we're used to
writing imperative, sequential code in Python.

gevent
------

gevent is an asynchronous framework, but it has the unique ability to allow the
developer to almost completely ignore the fact that the code is executed
asynchronously. Your code will run on an event loop using greenlets which
feel like real threads, but are very light weight, trivial to spawn, and run
off of the gevent event loop. gevent is capable of monkey patching the
necessary Python standard libraries like socket, such that when I/O or other
blocking calls happen the current greenlet will suspend and the event loop will
resume another greenlet while it waits for a response from the blocking
operation.  What this means for you is that you do not need to change your
Python code in order to run it in an asynchronous way.

While gevent can monkey patch the Python standard library, it can't do it all.
Fortunately, my favorite SQL database (PostgreSQL) already supports coroutines
and asynchronous execution. See Daniel Varrazzo's
`psycogreen <https://bitbucket.org/dvarrazzo/psycogreen/src/77a9c05f5229/
gevent/psyco_gevent.py>`__
repository for an example of configuring the psycopg2 driver to run under
gevent. This also means that developers can use their favorite ORM
(`SQLAlchemy <http://sqlalchemy.org>`__) on top of psycopg2 to talk to a
PostgreSQL database.

TicTacToe
---------

As an experiment, I wanted a small application that could demonstrate long
polling in action. Chat servers are boring and overused, so a friend came up
with the idea of implementing TicTacToe, enabling various mobile devices to
connect and play against each other. The API is pretty straightforward,
allowing players to connect, be assigned to a game, and make moves. These are
all basic functions that can be easily implemented using Pyramid's URL
Dispatch:

.. code-block:: python

    config.add_route('api.play', '/api/play')

    @view_config(route_name='api.play', request_method='POST', renderer='json')
    def play_view(request):
        # handle connecting a new player
        return {
            'game_id': game_id,
            'client_id': client_id,
            'name': name,
        }

Long polling comes in when ``playerX`` places an X in a location on the board and
we want to notify ``playerO`` that it is their turn to move. To accomplish this,
each game has a queue of events that have occurred to get the board to the state
it is at currently. Each player can then watch this queue for changes. Each
player in each game is then expected to connect to the server and maintain a
connection until a new update happens which we can return in the response.

Handling Updates
~~~~~~~~~~~~~~~~

There is already a
`well-documented <http://blog.gevent.org/2009/10/10/
simpler-long-polling-with-django-and-gevent/>`__ way to handle long polling in
a WSGI application by simply using ``gevent.event.Event`` to block the active
request until the server is ready to notify each client. The caveat to this
solution is that the resources your web framework has allocated for each
request will remain in memory until an update occurs, ending the request.

gevent has a nice trick to get around this problem. The ``gevent.queue.Queue``
class can be used as a blocking iterator, and for anyone who knows about WSGI,
the actual response of a WSGI application is an iterator. The underlying server
will attempt to iterate across the ``Queue``, returning each message to the
client as part of a chunked response. A ``Queue`` can be closed by pushing a ``StopIteration`` exception into it. This tells the WSGI server that the
response is complete.

TicTacToe utilizes this to be able to release the resources Pyramid has
allocated for a request (including possible database connections that you
want the server to reclaim as quickly as possible). Each client polling for an
update is turned into a ``Queue`` object which can be stored in memory to be
used when notifications occur.

The implementation of this basically boils down to a couple arrays. One holds
the timeline of updates, and the other stores the connected observers waiting
for notifications. The ``Game`` then becomes a mechanism for grouping these
together. When a new update is added to the ``Game``, all observers are
notified. Using the ``cursor`` pattern, the ability for clients to disconnect
and resume where they left off naturally falls out of the design.

.. code-block:: python

    class Game(object):
        def __init__(self, id):
            self.id = id
            self.observers = []
            self.updates = []
            self.cursor = 0

        def add_update(self, **kw):
            self.cursor += 1
            kw.setdefault('timestamp', datetime.utcnow().isoformat())
            kw.setdefault('cursor', self.cursor)
            self.updates.append(kw)
            self.notify_observers(kw)

        def add_observer(self, cursor=None):
            obs = Observer(game=self)
            if cursor == self.cursor or cursor is None:
                self.observers.append(obs)
            else:
                msg = json.dumps(self.updates[cursor+1])
                obs.put(msg)
                obs.put(StopIteration)
            return obs

        def remove_observer(self, obs):
            if obs in self.observers:
                obs.put(StopIteration)
                i = self.observers.index(obs)
                del self.observers[i]

        def notify_observers(self, msg):
            out = json.dumps(msg)
            for obs in self.observers:
                obs.put(out)
                obs.put(StopIteration)
            self.observers = []

The ``Observer`` is a simple subclass of a ``Queue`` that provides a way to
monitor how long a client has been connected. gevent currently doesn't
provide a good way to tell when disconnections occur, so at some point it's
important to kill active connections that may have stagnated.

.. code-block:: python

    class Observer(Queue):
        def __init__(self, *args, **kw):
            game = kw.pop('game')
            self.event = Event()
            Queue.__init__(self, *args, **kw)
            def reaper():
                self.event.clear()
                self.event.wait(30)
                game.remove_observer(self)
            gevent.spawn(reaper)

        def get(self, *args, **kw):
            self.event.set()
            return Queue.get(self, *args, **kw)

The actual Pyramid code for handling the long polling connections becomes
trivial, as all we have to do is turn the connection into an ``Observer``
which we can return as the response.

.. code-block:: python

    config.add_route('api.updates', '/api/updates/{game_id}')

    @view_config(route_name='api.updates', request_method='GET')
    def updates_view(request):
        game_id = request.GET.get('game_id')
        cursor = request.GET.get('cursor', 0)
        game = find_game(game_id)

        r = Response()
        r.content_type = 'application/json'
        r.app_iter = game.add_observer(cursor)
        return r

So the ``Response``'s ``app_iter`` is simply a blocking ``Queue`` to which we
can publish notifications!

The Code
~~~~~~~~

The full code is available on Github at https://github.com/mmerickel/tictactoe.
The code also includes an iOS client which was developed with the help of
employees at `Componica <http://www.componica.com>`__.
.
