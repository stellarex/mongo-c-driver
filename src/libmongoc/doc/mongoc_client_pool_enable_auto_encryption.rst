:man_page: mongoc_client_pool_enable_auto_encryption

mongoc_client_pool_enable_auto_encryption()
===========================================

Synopsis
--------

.. code-block:: c

   bool
   mongoc_client_pool_enable_auto_encryption (mongoc_client_pool_t *pool,
                                              mongoc_auto_encryption_opts_t* opts,
                                              bson_error_t* error);

Enable automatic client side encryption on a :symbol:`mongoc_client_pool_t`. Requires libmongoc to be built with support for In-Use Encryption. See :doc:`in-use-encryption` for instructions to enable In-Use Encryption in libmongoc.

Automatic encryption is an enterprise-only feature that only applies to operations on a collection. Automatic encryption is not supported for operations on a database or view, and operations that are not bypassed will result in error. To bypass automatic encryption for all operations, bypass automatic encryption with :symbol:`mongoc_auto_encryption_opts_set_bypass_auto_encryption()` in ``opts``.

Automatic encryption requires the authenticated user to have the `listCollections privilege action <https://docs.mongodb.com/manual/reference/command/listCollections/#dbcmd.listCollections>`_.

Enabling automatic encryption reduces the maximum message size and may have a negative performance impact.

Parameters
----------

* ``client``: A :symbol:`mongoc_client_t`.
* ``opts``: A required :symbol:`mongoc_auto_encryption_opts_t`.
* ``error``: A :symbol:`bson_error_t` which is set on error.

Returns
-------

Returns ``true`` if successful. Returns ``false`` and sets ``error`` otherwise.

.. seealso::

  | :symbol:`mongoc_auto_encryption_opts_t`

  | :symbol:`mongoc_client_enable_auto_encryption()`

  | :doc:`in-use-encryption` for libmongoc

  | The MongoDB Manual for `Client-Side Field Level Encryption <https://docs.mongodb.com/manual/core/security-client-side-encryption/>`_

  | The MongoDB Manual for `Queryable Encryption <https://www.mongodb.com/docs/manual/core/queryable-encryption/>`_

