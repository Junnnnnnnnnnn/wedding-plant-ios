package app.weddingplant.ui.main

import android.app.Application
import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import app.weddingplant.AppContainer
import app.weddingplant.core.time.Kst
import app.weddingplant.domain.AdGate
import app.weddingplant.ui.ContainerViewModelFactory
import app.weddingplant.ui.LocalAppContainer
import app.weddingplant.ui.components.ads.LocalAdsHost
import app.weddingplant.ui.components.ads.PreviewAds
import app.weddingplant.ui.pass.PassViewModel
import app.weddingplant.ui.theme.WeddingPlantTheme
import java.io.File
import java.io.FileOutputStream
import java.util.Base64
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 홈 ① 광고 자리 — 실제 홈 화면에 견본 광고(`PreviewAds`)를 넣고 **「이번 달에 할 일」 다음**에 오는지, 머리 면 · 두 자리
 * 스냅이 그대로인지 봅니다. 판정이 「패스 사용 중」이면 칸이 없어야 합니다.
 *
 * 목 서버를 백엔드로 둔 컨테이너로 띄웁니다(`HomeScrollRecordTest` 와 같음). 캡처: `files/shots/home-ad-*.png`.
 */
class AllScreenReviewShotTest {
    private val instrument get() = InstrumentationRegistry.getInstrumentation()
    private lateinit var server: MockWebServer
    private lateinit var container: AppContainer
    private var savedToken: String? = null
    private var onboarding = false

    @Volatile
    private var planned = "{\"total\":0,\"list\":[]}"

    @Before
    fun setup() {
        server = MockWebServer()
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = respond(request.path.orEmpty())
        }
        server.start()
        container = AppContainer(instrument.targetContext.applicationContext as Application, server.url("/").toString().trimEnd('/'))
        savedToken = container.tokenStore.get()
        container.tokenStore.set(fakeJwt("me-1"))
        // 지난번 판정이 첫 그림으로 뜨지 않게(실행 순서에 따라 화면이 달라지지 않게)
        container.homeInvitation.clearAll()
        val month = Kst.today().withDayOfMonth(1)
        val now = (1..3).map { i ->
            "{\"id\":$i,\"categoryName\":\"스드메\",\"title\":\"이번 달 플랜 $i\",\"amount\":${i * 100},\"startDate\":\"${month.plusDays((i * 7).toLong())}\",\"status\":\"NORMAL\"}"
        }
        val later = (4..5).map { i ->
            "{\"id\":$i,\"categoryName\":\"예식장\",\"title\":\"다음 달 플랜 $i\",\"amount\":${i * 100},\"startDate\":\"${month.plusMonths(1).plusDays(i.toLong())}\",\"status\":\"NORMAL\"}"
        }
        planned = "{\"total\":5,\"list\":[${(now + later).joinToString(",")}]}"
    }

    @After
    fun teardown() {
        val saved = savedToken
        if (saved.isNullOrBlank()) container.tokenStore.clear() else container.tokenStore.set(saved)
        server.shutdown()
    }

    private fun ok(data: String) = MockResponse().setResponseCode(200)
        .setHeader("Content-Type", "application/json")
        .setBody("{\"result\":true,\"data\":$data}")

    private fun respond(path: String): MockResponse = when {
        // 홈의 청첩장 입구(2026-10-12) — 패스 없음으로 정해 둡니다(모르는 경로의 기본 응답으로 읽히지 않게)
        onboarding && path == "/plan/user" -> ok("""{"id":"me-1"}""")
        path.startsWith("/plan/my-invitation") -> ok("{\"roomId\":7,\"hasPass\":false,\"canEdit\":false,\"invitation\":null}")
        path.contains("/amount/category-chart") -> ok("""{"list":[{"categoryName":"웨딩홀","totalAmount":1400,"usedAmount":1200},{"categoryName":"스튜디오","totalAmount":600,"usedAmount":450},{"categoryName":"신혼여행","totalAmount":820,"usedAmount":0},{"categoryName":"예물","totalAmount":650,"usedAmount":0},{"categoryName":"드레스","totalAmount":500,"usedAmount":0},{"categoryName":"메이크업","totalAmount":180,"usedAmount":0},{"categoryName":"본식스냅","totalAmount":0,"usedAmount":500}]}""")
        path.contains("/amount/detail") -> ok("""{"initialCapital":5000,"totalPlannedAndUsedAmount":3400,"plannedUseAmount":1250,"usedAmount":2150}""")
        path.startsWith("/plan/feed/list") -> ok("""{"total":1,"list":[{"id":1,"categoryName":"스튜디오","title":"라뮈에스튜디오","amount":450,"isAmountPublic":true,"region":"서울 강남구","rating":5,"body":"원본 800장 다 받았어요.","authorDDay":131,"authorRole":"BRIDE","helpfulCount":12,"isMine":false}]}""")
        path.startsWith("/plan/feed/my/status") -> ok("""{"postCount":2,"receivedHelpfulCount":5,"postableScheduleCount":1}""")
        path.startsWith("/plan/user/total-amount") || path.startsWith("/plan/room/total-amount") ->
            ok("{\"totalAmount\":4200,\"usedAmount\":1350,\"remainingAmount\":2850}")
        path.startsWith("/plan/user") -> ok(
            "{\"name\":\"지수\",\"weddingDate\":\"2026-12-12\",\"weddingHall\":\"더채플앳청담\",\"budget\":4200,\"roomId\":7,\"members\":[],\"chatRooms\":[]}",
        )
        path.startsWith("/plan/room/list") -> ok("{\"total\":0,\"list\":[]}")
        path.startsWith("/plan/room/7") -> ok("{\"name\":\"지수\",\"members\":[{\"planUserId\":\"me-1\",\"name\":\"지수\",\"permission\":\"OWNER\"}]}")
        path.startsWith("/plan/schedule") && path.contains("status=NORMAL") -> ok(planned)
        path.startsWith("/plan/pass/room") -> ok("{\"hasPass\":false}")
        path.startsWith("/plan/brag/my") -> ok("{\"published\":false}")
        else -> ok("{\"total\":0,\"list\":[]}")
    }

    private fun fakeJwt(planUserId: String): String {
        val enc = Base64.getUrlEncoder().withoutPadding()
        val header = enc.encodeToString("{\"alg\":\"none\"}".toByteArray())
        val payload = enc.encodeToString("{\"planUserId\":\"$planUserId\",\"sub\":\"1\"}".toByteArray())
        return "$header.$payload.sig"
    }

    private fun launchHome(gate: AdGate, screen: String): ActivityScenario<ComponentActivity> {
        val scenario = ActivityScenario.launch(ComponentActivity::class.java)
        scenario.onActivity { activity ->
            activity.enableEdgeToEdge()
            activity.setContent {
                WeddingPlantTheme {
                    CompositionLocalProvider(
                        LocalAppContainer provides container,
                        LocalAdsHost provides PreviewAds(gate),
                    ) {
                        val vm: MainViewModel = viewModel(factory = ContainerViewModelFactory(container) { MainViewModel(it) })
                        val passVm: PassViewModel = viewModel(factory = ContainerViewModelFactory(container) { PassViewModel(it) })
                        when (screen) {
                            "home" -> MainScreen(vm, passVm, {}, {}, {}, {}, {}, motionEnabled = false)
                            "budget" -> {
                                val m: app.weddingplant.ui.budget.BudgetDetailViewModel = viewModel(factory = ContainerViewModelFactory(container) { app.weddingplant.ui.budget.BudgetDetailViewModel(it, null) })
                                app.weddingplant.ui.budget.BudgetDetailScreen(m, passVm, {}, {})
                            }
                            "profile" -> {
                                val m: app.weddingplant.ui.user.UserViewModel = viewModel(factory = ContainerViewModelFactory(container) { app.weddingplant.ui.user.UserViewModel(it) })
                                val auth: app.weddingplant.ui.auth.AuthViewModel = viewModel(factory = ContainerViewModelFactory(container) { app.weddingplant.ui.auth.AuthViewModel(it) })
                                app.weddingplant.ui.user.UserScreen(container, m, auth, passVm, {}, {}, onBack = {})
                            }
                            "landing" -> {
                                val auth: app.weddingplant.ui.auth.AuthViewModel = viewModel(factory = ContainerViewModelFactory(container) { app.weddingplant.ui.auth.AuthViewModel(it) })
                                app.weddingplant.ui.landing.LandingScreen(auth)
                            }
                            "feed" -> {
                                val m: app.weddingplant.ui.feed.FeedViewModel = viewModel(factory = ContainerViewModelFactory(container) { app.weddingplant.ui.feed.FeedViewModel(it) })
                                app.weddingplant.ui.feed.FeedScreen(m, {}, {})
                            }
                        }
                    }
                }
            }
        }
        return scenario
    }

    private fun node(text: String): AccessibilityNodeInfo? {
        val root = instrument.uiAutomation.rootInActiveWindow ?: return null
        root.refresh()
        fun visit(n: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
            if (n == null) return null
            n.refresh()
            val label = (n.text ?: n.contentDescription)?.toString()?.replace("⁠", "")
            if (label != null && label.contains(text)) return n
            for (i in 0 until n.childCount) visit(n.getChild(i))?.let { return it }
            return null
        }
        return visit(root)
    }

    private fun top(text: String): Int? = node(text)?.let { n -> Rect().also { n.getBoundsInScreen(it) }.top }

    private fun waitText(text: String, timeoutMs: Long = 10_000) {
        val until = System.currentTimeMillis() + timeoutMs
        while (node(text) == null && System.currentTimeMillis() < until) Thread.sleep(100)
        assertTrue("'$text' 가 떠야 한다", node(text) != null)
    }

    private fun swipe(fromY: Int, toY: Int, ms: Int) {
        val x = instrument.targetContext.resources.displayMetrics.widthPixels / 2
        val pfd = instrument.uiAutomation.executeShellCommand("input touchscreen swipe $x $fromY $x $toY $ms")
        android.os.ParcelFileDescriptor.AutoCloseInputStream(pfd).use { it.readBytes() }
    }

    private fun shot(name: String) {
        val dir = File(instrument.targetContext.filesDir, "shots").apply { mkdirs() }
        val bmp = instrument.uiAutomation.takeScreenshot()
        FileOutputStream(File(dir, "$name.png")).use { bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun review(screen: String, anchor: String) {
        launchHome(AdGate.SHOW, screen).use {
            waitText(anchor)
            Thread.sleep(1200)
            shot("review-native-$screen-top")
            val h = instrument.targetContext.resources.displayMetrics.heightPixels
            swipe(h * 4 / 5, h / 4, 450); Thread.sleep(650)
            shot("review-native-$screen-middle")
            repeat(4) { swipe(h * 4 / 5, h / 4, 350); Thread.sleep(250) }
            shot("review-native-$screen-bottom")
        }
    }
    @Test fun reviewHome() = review("home", "결혼식까지")
    @Test fun reviewBudget() = review("budget", "예산")
    @Test fun reviewProfile() = review("profile", "지수")
    @Test fun reviewLanding() = review("landing", "카카오로 시작하기")
    @Test fun reviewFeed() = review("feed", "다른 커플은 얼마 썼을까")
    @Test fun reviewOnboarding() {
        onboarding = true
        lateinit var model: app.weddingplant.ui.setting.SettingViewModel
        ActivityScenario.launch(ComponentActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                activity.enableEdgeToEdge()
                activity.setContent {
                    WeddingPlantTheme {
                        CompositionLocalProvider(LocalAppContainer provides container) {
                            model = viewModel(factory = ContainerViewModelFactory(container) { app.weddingplant.ui.setting.SettingViewModel(it) })
                            app.weddingplant.ui.setting.SettingScreen(model, {})
                        }
                    }
                }
            }
            Thread.sleep(1400)
            for (step in app.weddingplant.ui.setting.SettingViewModel.Step.entries) {
                instrument.runOnMainSync { model.goTo(step) }
                Thread.sleep(800)
                shot("review-onboarding-${step.name.lowercase()}")
            }
        }
    }

}
