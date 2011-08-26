public: yes
tags: [pyramid]
summary: |
    Pyramid 1.2 goes a long way toward making pyramid_handlers obsolete.

Outgrowing Pyramid Handlers
===========================

`pyramid_handlers
<https://docs.pylonsproject.org/projects/pyramid_handlers/dev/>`_ is a
package introduced to the `Pyramid <https://pylonsproject.org>`_ suite of
supported addons in Pyramid 1.0 as a way to ease the transition for
developers coming from the Pylons framework during the public merger of the
two projects. It closely maps previous functionality from the Pylons concept
of ``controllers``. Handlers provide three main features:

1. Grouping of relevant code. A class provides a logical way to organize a
   bunch of code related to a section of your site.

2. Syntactic sugar for exposing several URLs under a single route name. This
   can help with generation and configuration verbosity.

3. A single location for routing. It's possible to look at the
   ``add_handler`` calls and determine not only what URLs are supported but
   also where the code is that is handling those URLs.

Some handler-style code:

.. code-block:: python

    # main.py
    config.add_handler('home', '/',
                       handler='handlers.main.MainHandler',
                       action='index')
    config.add_handler('main', '/{action}',
                       handler='handlers.main.MainHandler',
                       path_info=r'/(?!index)')
    config.add_handler('search', '/search/{id}',
                       handler='handlers.main.MainHandler',
                       action='search')

    # handlers/main.py
    class MainHandler(object):
        def __init__(self, request):
            self.request = request

        @action(renderer='home.mako')
        def index(self):
            return {
                # vars exposed for home.mako
            }

        @action(renderer='login.mako')
        def login(self):
            return {
                # vars exposed for login.mako
            }

        @action(renderer='logout.mako')
        def logout(self):
            return {
                # vars exposed for logout.mako
            }

        @action(renderer='search.mako')
        def search(self):
            return {}

Moving to Pyramid-Core
----------------------

Pyramid generalizes the relationship between URLs and views much further
than the original Pylons routing where there was one class method registered
per URL. Pyramid separates URLs from code by way of view lookup. It has no
constraints that the view must be a class (but it can!). Once the
matching route pattern has been computed for a URL, it then does a second
step to determine which view to call. Each of these steps may have predicates
that can determine per-request whether the route or the view should be
invoked.

Given that multiple views can be attached to a single route, Pyramid 1.2
introduces the ``match_param`` view predicate which helps the user. This
will allow the user to register multiple views for the same route and then
control the dispatch based on a pattern in the URL, e.g. ``{action}``.

Below is the handler-style code translated into vanilla ``add_route`` and
``view_config`` URL dispatch.

.. code-block:: python

    # main.py
    config.add_route('home', '/')
    config.add_route('main', '/{action}')
    config.add_route('search', '/search/{id}')

    config.scan() # required to find code decorated by view_config

    # views/main.py
    class MainHandler(object):
        def __init__(self, request):
            self.request = request

        @view_config(route_name='home', renderer='home.mako')
        def index(self):
            return {
                # vars exposed for home.mako
            }

        @view_config(route_name='main', match_param='action=login',
                     renderer='login.mako')
        def login(self):
            return {
                # vars exposed for login.mako
            }

        @view_config(route_name='main', match_param='action=logout',
                     renderer='logout.mako')
        def logout(self):
            return {
                # vars exposed for logout.mako
            }

        @view_config(route_name='main', match_param='action=search',
                     renderer='search.mako')
        @view_config(route_name='search', renderer='search.mako')
        def search(self):
            return {
                # vars exposed for search.mako
            }

What are the advantages?
++++++++++++++++++++++++

Explicit is better than implicit
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Very rarely do you actually want to expose *all* of the methods in a class
via the same URL patterns. By being explicit, the configuration avoids
unintended side-effects. For example, in the ``pyramid_handlers`` code above,
we have to be careful to avoid `/index` being a valid URL by way of the
``path_info`` regular expression predicate and any other methods we add to
the class need to take into consideration all of the URL patterns it may
implicitly match. This is the definition of a maintenance nightmare.

Separation of concerns
~~~~~~~~~~~~~~~~~~~~~~

In the handler code the actions are embedded in not only the methods
decorated by ``@action`` but also in some of the ``add_handler`` calls,
e.g. the ``search`` route. Notice that in the Pyramid code the
``MainHandler.search`` method is very clearly handling two different routes,
at the point where the view is defined. This serves as a reminder while
implementing those functions that it needs to account for both possibilities.

Fewer dependencies
~~~~~~~~~~~~~~~~~~

Removing the need for ``pyramid_handlers``, while small, encourages users to
learn the Pyramid API which is well-designed, extensible and capable of
handling a large number scenarios on its own merit.

What are the disadvantages?
+++++++++++++++++++++++++++

The major feature that ``pyramid_handlers`` provides is a central location
where URLs are mapped to code. Using Pyramid's ``add_route`` and ``add_view``
APIs provides an explicit separation between the URL and the view to which
this URL could map. Pyramid tries to help by providing ``paster`` functions
like ``pviews`` that will show, for a URL, what views exist. However, some
developers will prefer the ability to look at the ``add_handler`` calls
directly and determine not only what URL is supported, but what code will be
executed for that URL.

Why is Pyramid's routing awesome?
+++++++++++++++++++++++++++++++++

Whether you use ``pyramid_handlers`` or the routing directly, hopefully you
can gain an appreciation for the configurability of Pyramid's URL Dispatch.
While Pyramid's configuration API is verbose, you are greatly rewarded by
way of fast runtimes and simpler view code. Since multiple views may be
attached to a route, you can leave the dispatch up to Pyramid, allowing your
views to focus on their single purpose, without requiring a bunch of
``if``-statements to handle different functionality.
