package com.sadat.jamaattime.focusguard

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.min

internal object FocusGuardOverlayViewFactory {

    fun create(
        context: Context,
        tempAllowMinutes: Int,
        quickAllowEnabled: Boolean,
        onGoBack: () -> Unit,
        onAllow: (minutes: Int) -> Unit,
    ): View {
        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.parseColor("#CC000000"))
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val pad = dp(context, 24)
            setPadding(pad, pad, pad, pad)
            val bg = GradientDrawable().apply {
                cornerRadius = dp(context, 20).toFloat()
                setColor(Color.parseColor("#FF1B1B1B"))
            }
            background = bg
            layoutParams = FrameLayout.LayoutParams(
                calculateCardWidth(context),
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            )
        }

        card.addView(
            TextView(context).apply {
                text = "Focus Guard Active"
                setTextColor(Color.WHITE)
                textSize = 24f
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
            }
        )

        card.addView(
            TextView(context).apply {
                text = "\u09B6\u09B0\u09CD\u099F \u09AD\u09BF\u09A1\u09BF\u0993 \u09AC\u09CD\u09B2\u0995\u09A1\u0964\n" +
                    "\u099A\u09CB\u0996\u0995\u09C7 \u09AC\u09BF\u09B6\u09CD\u09B0\u09BE\u09AE \u09A6\u09BF\u09A8 \u098F\u09AC\u0982 \u0995\u09BE\u099C\u09C7 \u09AB\u09BF\u09B0\u09C1\u09A8\u0964\n" +
                    "\u09B8\u09AE\u09DF \u098F\u09AC\u0982 \u09B8\u09CD\u09AC\u09BE\u09B8\u09CD\u09A5\u09CD\u09AF \u0986\u09B2\u09CD\u09B2\u09BE\u09B9\u09B0 \u09A6\u09C7\u0993\u09DF\u09BE \u09AC\u09BF\u09B6\u09C7\u09B7 \u0986\u09AE\u09BE\u09A8\u09A4, \u098F\u09B0 \u0985\u09AC\u09AE\u09C2\u09B2\u09CD\u09AF\u09BE\u09DF\u09A8 \u0995\u09B0\u09AC\u09C7\u09A8 \u09A8\u09BE\u0964"
                setTextColor(Color.parseColor("#CCFFFFFF"))
                textSize = 18f
                setTypeface(typeface, Typeface.BOLD)
                setLineSpacing(dp(context, 4).toFloat(), 1.2f)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply {
                    topMargin = dp(context, 10)
                    bottomMargin = dp(context, 20)
                }
            }
        )

        card.addView(
            Button(context).apply {
                text = "Go Back"
                setOnClickListener { onGoBack() }
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
            }
        )

        if (quickAllowEnabled) {
            card.addView(
                Button(context).apply {
                    text = "Allow $tempAllowMinutes min"
                    setOnClickListener { onAllow(tempAllowMinutes) }
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = dp(context, 8)
                    }
                }
            )
        }

        root.addView(card)
        return root
    }

    private fun calculateCardWidth(context: Context): Int {
        val screenWidth = context.resources.displayMetrics.widthPixels
        val sideMargin = dp(context, 20)
        val ninetyPercentWidth = (screenWidth * 0.9f).toInt()
        val maxTabletWidth = dp(context, 480)
        val boundedByMargins = (screenWidth - (sideMargin * 2)).coerceAtLeast(dp(context, 240))
        return min(ninetyPercentWidth, min(maxTabletWidth, boundedByMargins))
    }

    private fun dp(context: Context, value: Int): Int {
        val density = context.resources.displayMetrics.density
        return (value * density).toInt()
    }
}
