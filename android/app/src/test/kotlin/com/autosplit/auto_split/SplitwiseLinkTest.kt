package com.autosplit.auto_split

import org.junit.Assert.assertEquals
import org.junit.Test

/** The link and notification text, which have no Android dependencies. */
class SplitwiseLinkTest {
    private val base = "https://secure.splitwise.com/applinks/expenses/new"

    @Test
    fun amountIsPlainDecimalRupees() {
        assertEquals("450", SplitwiseLauncher.amountText(45000))
        assertEquals("450.50", SplitwiseLauncher.amountText(45050))
        assertEquals("450.05", SplitwiseLauncher.amountText(45005))
        assertEquals("1", SplitwiseLauncher.amountText(100))
        assertEquals("0.99", SplitwiseLauncher.amountText(99))
    }

    @Test
    fun urlEncodesDescriptionAndSkipsGroupWhenUnset() {
        assertEquals(
            "$base?description=Chai%20test&amount=250&currency_code=INR",
            SplitwiseLauncher.url(25000, "Chai test"),
        )
        assertEquals(
            "$base?description=Caf%C3%A9%20%26%20Co&amount=450.50&currency_code=INR",
            SplitwiseLauncher.url(45050, " Café & Co "),
        )
    }

    @Test
    fun urlCarriesGroupId() {
        assertEquals(
            "$base?description=Swiggy&amount=450&currency_code=INR&group_id=12345678",
            SplitwiseLauncher.url(45000, "Swiggy", 12345678L),
        )
    }

    @Test
    fun notificationTitleUsesIndianGrouping() {
        assertEquals("₹450 · Swiggy", SplitNotifications.title(45000, "Swiggy"))
        assertEquals("₹1,250.50 · Rent", SplitNotifications.title(125050, "Rent"))
        assertEquals("₹1,25,000 · Flat", SplitNotifications.title(12500000, "Flat"))
        assertEquals("₹12,345 · X", SplitNotifications.title(1234500, "X"))
    }
}
