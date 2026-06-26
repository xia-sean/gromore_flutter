package com.gromore.flutter

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.util.Log

class GromoreFlutterInitProvider : ContentProvider() {
  override fun onCreate(): Boolean {
    val appContext = context?.applicationContext ?: return false
    GromoreFlutterInitializer.autoInitializeIfNeeded(appContext) { level, message, tag ->
      when (level) {
        "error" -> Log.e(tag, message)
        "warn" -> Log.w(tag, message)
        "debug" -> Log.d(tag, message)
        else -> Log.i(tag, message)
      }
    }
    return true
  }

  override fun query(
    uri: Uri,
    projection: Array<out String>?,
    selection: String?,
    selectionArgs: Array<out String>?,
    sortOrder: String?
  ): Cursor? = null

  override fun getType(uri: Uri): String? = null

  override fun insert(uri: Uri, values: ContentValues?): Uri? = null

  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

  override fun update(
    uri: Uri,
    values: ContentValues?,
    selection: String?,
    selectionArgs: Array<out String>?
  ): Int = 0
}
