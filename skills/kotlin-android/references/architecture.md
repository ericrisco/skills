# End-to-end wired feature: offline-first article list

A complete, compilable feature that follows the UDF layered architecture. Package layout is
**package-by-feature**; the data layer is the source of truth (Room), refreshed from the
network (Retrofit). Adapt names; keep the shape.

```text
com.example.app
├── App.kt                         // @HiltAndroidApp
├── core
│   ├── di/DispatchersModule.kt    // @IoDispatcher qualifier + binding
│   └── result/AppError.kt         // sealed error type
└── feature/articles
    ├── data
    │   ├── ArticleApi.kt          // Retrofit suspend service
    │   ├── ArticleDao.kt          // Room DAO -> Flow
    │   ├── ArticleEntity.kt       // Room @Entity
    │   ├── ArticleDto.kt          // @Serializable wire model
    │   ├── ArticleRepositoryImpl.kt
    │   └── ArticlesDataModule.kt  // Hilt module
    ├── domain
    │   ├── Article.kt             // domain model
    │   └── ArticleRepository.kt   // interface
    └── ui
        ├── ArticlesUiState.kt
        ├── ArticlesViewModel.kt
        └── ArticlesScreen.kt
```

## Domain

```kotlin
// domain/Article.kt
data class Article(val id: String, val title: String, val body: String)

// domain/ArticleRepository.kt
interface ArticleRepository {
    fun observeArticles(): Flow<List<Article>>
    suspend fun refresh()
}
```

## Data

```kotlin
// data/ArticleDto.kt
@Serializable
data class ArticleDto(
    val id: String,
    val title: String,
    val body: String,
)

// data/ArticleApi.kt
interface ArticleApi {
    @GET("articles")
    suspend fun getArticles(): List<ArticleDto>
}

// data/ArticleEntity.kt
@Entity(tableName = "articles")
data class ArticleEntity(
    @PrimaryKey val id: String,
    val title: String,
    val body: String,
)

// data/ArticleDao.kt
@Dao
interface ArticleDao {
    @Query("SELECT * FROM articles ORDER BY title")
    fun observeAll(): Flow<List<ArticleEntity>>   // source of truth

    @Upsert
    suspend fun upsertAll(entities: List<ArticleEntity>)
}
```

```kotlin
// data/ArticleRepositoryImpl.kt
class ArticleRepositoryImpl @Inject constructor(
    private val api: ArticleApi,
    private val dao: ArticleDao,
    @IoDispatcher private val io: CoroutineDispatcher,
) : ArticleRepository {

    // UI observes Room only — never the network directly.
    override fun observeArticles(): Flow<List<Article>> =
        dao.observeAll().map { rows -> rows.map { it.toDomain() } }

    // Network writes into Room; the Flow above re-emits automatically.
    override suspend fun refresh() = withContext(io) {
        val remote = api.getArticles()
        dao.upsertAll(remote.map { it.toEntity() })
    }
}

private fun ArticleEntity.toDomain() = Article(id, title, body)
private fun ArticleDto.toEntity() = ArticleEntity(id, title, body)
```

## DI

```kotlin
// App.kt
@HiltAndroidApp
class App : Application()

// core/di/DispatchersModule.kt
@Qualifier @Retention(AnnotationRetention.BINARY)
annotation class IoDispatcher

@Module
@InstallIn(SingletonComponent::class)
object DispatchersModule {
    @Provides @IoDispatcher
    fun provideIo(): CoroutineDispatcher = Dispatchers.IO
}

// feature/articles/data/ArticlesDataModule.kt
@Module
@InstallIn(SingletonComponent::class)
abstract class ArticlesDataModule {
    @Binds
    abstract fun bindRepository(impl: ArticleRepositoryImpl): ArticleRepository
}
```

Provide `ArticleApi`, the Room `Database`, and `ArticleDao` from `@Provides` functions in a
network/database module (Retrofit builder with the kotlinx.serialization converter; the Room
`databaseBuilder`). Both are `@Singleton`.

## UI

```kotlin
// ui/ArticlesUiState.kt
sealed interface ArticlesUiState {
    data object Loading : ArticlesUiState
    data class Success(val articles: List<Article>) : ArticlesUiState
    data class Error(val message: String) : ArticlesUiState
}

// ui/ArticlesViewModel.kt
@HiltViewModel
class ArticlesViewModel @Inject constructor(
    private val repository: ArticleRepository,
) : ViewModel() {

    val uiState: StateFlow<ArticlesUiState> =
        repository.observeArticles()
            .map<List<Article>, ArticlesUiState> { ArticlesUiState.Success(it) }
            .catch { emit(ArticlesUiState.Error(it.message ?: "Unknown error")) }
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5_000),
                initialValue = ArticlesUiState.Loading,
            )

    init { refresh() }

    fun refresh() = viewModelScope.launch {
        runCatching { repository.refresh() }   // failure surfaces via the catch above
    }
}
```

```kotlin
// ui/ArticlesScreen.kt
@Composable
fun ArticlesRoute(viewModel: ArticlesViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    ArticlesScreen(state = state, onRetry = viewModel::refresh)
}

@Composable
fun ArticlesScreen(state: ArticlesUiState, onRetry: () -> Unit) {
    when (state) {
        ArticlesUiState.Loading -> Box(Modifier.fillMaxSize(), Alignment.Center) {
            CircularProgressIndicator()
        }
        is ArticlesUiState.Error -> Column {
            Text(state.message)
            Button(onClick = onRetry) { Text("Retry") }
        }
        is ArticlesUiState.Success -> LazyColumn {
            items(state.articles, key = { it.id }) { article ->
                ListItem(headlineContent = { Text(article.title) })
            }
        }
    }
}
```

## Why this shape

- **Room is the single source of truth.** `refresh()` writes the network result into Room;
  `observeArticles()` re-emits, so the UI updates without the ViewModel mediating data twice.
- **The Composable is stateless and previewable** — it takes `state` + `onRetry`, nothing else.
- **No leak path**: all coroutines live in `viewModelScope`; navigating away cancels them.
- **Testable**: inject a fake `ArticleRepository`; inject `@IoDispatcher` as a test dispatcher.
