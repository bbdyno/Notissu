# 숭실대학교 학사 조직별 공지 게시판 목록 (2026-10-29 조사)

- 출처: ssu.ac.kr `교육·연구 > 대학소개` 의 단과대학 페이지 12개, 각 학과 소개 페이지의 "공지사항 / 학과 홈페이지" 링크, `교육·연구 > 대학원` 페이지, 그리고 각 홈페이지 메뉴. 모두 `curl -sL` 로 직접 열었다.
- **확인** = 1페이지를 직접 받아서 글 목록(제목·링크)이 보임. **확인(API)** = 페이지는 빈 껍데기이고 브라우저가 부르는 API를 직접 호출해 글 목록을 받음. **미확인** = 추측했거나 목록을 보지 못함.
- URL의 한글 경로는 읽기 쉽게 풀어서 적었다. 앱에서는 퍼센트 인코딩해서 요청해야 한다.
- "최근 글"은 1페이지에서 본 가장 최근 날짜다. 게시판이 살아 있는지 판단하는 데 쓰면 된다.

## 엔진별 페이지 넘김·검색 규칙

| 코드 | 엔진(추정) | 페이지 넘김 | 검색 | 글 링크 형태 |
|---|---|---|---|---|
| WP | WordPress, 학교 공통 테마 | `<board>/page/N/` | `?keyword=<검색어>` (`select`=검색 필드) | `<board>/?term_id&slug=<글번호>` |
| WP-q | WordPress, 쿼리형 고유주소 (수학과) | `?page_id=977&paged=N` | `&keyword=` | `?page_id=977&term_id&slug=<번호>` |
| G5 | 그누보드 | `&page=N` | `&sfl=wr_subject&stx=<검색어>` | `&wr_id=<번호>` |
| BID | 자체 PHP, `boardid` 형 (전기·화공·정보사회) | `&offset=10·20·…` (10개 단위) | `&sk=<검색어>` (`sw`=필드) | `&mode=view&idx=<번호>` |
| INFO | 자체 PHP (전자정보공학부) | `?pNo=N&code=notice` | 정렬 `sorder`만 있음 | `?m=v&idx=<번호>&code=notice` |
| ME | 자체 PHP (기계공학부) | `?page=N` | `&search=<검색어>&type=` | `?admin_mode=read&no=<번호>` |
| TBL | 자체 PHP, `tbl=bbsNN` 형 (신소재) | `&page=N` | `&findType=&findWord=` | `&mode=VIEW&num=<번호>` |
| NV | 자체 PHP, `notice.html` 형 (AI융합·정보통계) | `?page=N` (`fnGoPage`) | `searchKey`/`searchValue` | `notice_view.html?category=1&idx=<번호>` |
| BIZ | Java `list.do` (경영학부) | `&page=N` | `&sc_title=<검색어>` | `read.do?aId=bbs<번호>&bId=…` |
| CI | CodeIgniter 계열 추정 (금융경제학과) | `?page=N` | `&sfield=&skeyword=` | `/post/<번호>` |
| NX-SSR | Next.js, 서버 렌더 (ai.ssu.ac.kr) | `?pageNum=N` (`page`는 무시됨) | `?condition=&keyword=` | `/board/notice/<번호>` |
| NX-API1 | Next.js 화면 + REST API (글로벌미디어·디지털미디어) | API `GET /v1/board/?page=<N-1>&size=15&menuId=<id>&title=<검색어>` (page는 0부터) | API `title=` | JSON `data.boards[].id` |
| NX-API2 | Next.js 화면 + REST API (AI전문대학원·중소기업대학원) | API `GET https://<host>/api/board/content/list?pageNum=N&boardEnName=notice` | API `&boardTitle=<검색어>` | JSON `data.content.list[].boardContentId` |
| FILM | 자체 JSON (영화예술전공) | `GET /notice/notice_list?LastNoticeIndex=<마지막 NoticeIndex>` (처음 0, 커서 방식) | 없음 | JSON `data_list[].NoticeIndex` |
| DISU | 자체 (혁신융합대학 사업단 통합 사이트) | `&page=N` (1부터) | `&q=<검색어>` (`qt`, `sc`) | `?md=v&bbsidx=<번호>` |
| DORM | 자체 PHP, EUC-KR (기숙사) | `&next=0·15·30…` (15개 단위) | `&Q=<검색어>` | `javascript:viewContent('1','<번호>')` → `viewform=B0001_noticeboard_view` |
| ASP | ASP (입학처) | `?page=N&flag=<분류>` | `&srchoption=&keyword=` | |
| JSON | 정적 JSON (가상융합대학원) | 없음 (`/data/content.json` 의 `notice` 배열 전체) | 없음 | |
| PYX | Pyxis 도서관 API | `offset=&max=` | | |

## 1. 학부

| 소속 | 단위명 | 도메인 | 공지 게시판 URL (1페이지) | 엔진 | 확인 | 최근 글 | 비고 |
|---|---|---|---|---|---|---|---|
| 인문대학 | 기독교학과 | docs.ssu.ac.kr | https://docs.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-09 | |
| 인문대학 | 국어국문학과 | korlan.ssu.ac.kr | https://korlan.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-09 | `page/2/`, `?keyword=` 동작 직접 확인 |
| 인문대학 | 영어영문학과 | englan.ssu.ac.kr | https://englan.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-10 | ssu.ac.kr 소개 페이지의 "공지사항" 링크는 `/대학원/공지사항/`(대학원 게시판)을 가리킴 |
| 인문대학 | 독어독문학과 | gerlan.ssu.ac.kr | https://gerlan.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-10 | |
| 인문대학 | 불어불문학과 | france.ssu.ac.kr | https://france.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-10 | |
| 인문대학 | 중어중문학과 | chilan.ssu.ac.kr | https://chilan.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-09 | |
| 인문대학 | 일어일문학과 | japanstu.ssu.ac.kr | https://japanstu.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-09 | 보조: `/학과사무실알림/채용공고/` |
| 인문대학 | 철학과 | philo.ssu.ac.kr | https://philo.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-10 | 보조: `/학과사무실알림/장학-및-공모전/` |
| 인문대학 | 사학과 | history.ssu.ac.kr | https://history.ssu.ac.kr/학과소식/학과공지/ | WP | 확인 | 2026-09 | 보조: `/학과소식/학술·비교과·행사-공지/`, `/학과소식/장학·채용·봉사-공지/`, `/학생활동/학생활동-공지/` |
| 인문대학 | 문예창작전공 | creativewriting.ssu.ac.kr | https://creativewriting.ssu.ac.kr/공지/공지사항/ | WP | 확인 | (날짜 표기 없음) | 보조: `/공지/공지사항/공모전-공지/` |
| 인문대학 | 영화예술전공 | ssfilm.ssu.ac.kr | http://ssfilm.ssu.ac.kr/notice/notice_list?LastNoticeIndex=0 (화면: /notice/index) | FILM | 확인(API) | 2026-10-27 | 화면은 JSON을 받아 그림. `restCount`로 남은 개수 확인 |
| 인문대학 | 스포츠학부 | sports.ssu.ac.kr | http://sports.ssu.ac.kr/자료실/신앙자료실/ | WP | 확인 | 2026-07 | 주소 이름은 "신앙자료실"이지만 페이지 제목·내용은 스포츠학부 공지. 홈 메뉴 "공지사항"도 이 주소. ssu.ac.kr 소개 페이지의 교수·교과 링크는 교목실 주소로 잘못 걸려 있음 |
| 자연과학대학 | 수학과 | math.ssu.ac.kr | https://math.ssu.ac.kr/?page_id=977 | WP-q | 확인 | 2026-09 | 보조: 강의공지 `?page_id=979` |
| 자연과학대학 | 물리학과 | physics.ssu.ac.kr | https://physics.ssu.ac.kr/게시판/공지사항/ | WP | 확인 | 2026-10 | 보조: `/게시판/학과소식/`, `/졸업논문/졸업공지/` |
| 자연과학대학 | 화학과 | chem.ssu.ac.kr | https://chem.ssu.ac.kr/자유게시판/공지사항/ | WP | 확인 | 2026-02 | 하위 분류 `/공지사항/학과소식/`·`취업정보/`·`장학제도/`·`기타-공지/`·`융합전공/` |
| 자연과학대학 | 정보통계·보험수리학과 | stat.ssu.ac.kr | http://stat.ssu.ac.kr/notice.html?category=1 | NV | 확인 | 2026-10-27 | `&page=2` 동작 확인. category 3=세미나소식, 4=학과소식, 2=채용·공모전 성격. 주소에 PHPSESSID가 붙어 나오지만 없어도 됨 |
| 자연과학대학 | 의생명시스템학부 | bioinfo.ssu.ac.kr | https://bioinfo.ssu.ac.kr/게시판/공지사항/ | WP | 확인 | 2026-09 | 보조: `/게시판/학부-소식/` |
| 법과대학 | 법학과 | law.ssu.ac.kr | https://law.ssu.ac.kr/menu5/m5sub3/ | WP | 확인 | 2026-10-29 | |
| 법과대학 | 국제법무학과 | lawyer.ssu.ac.kr | https://lawyer.ssu.ac.kr/학과-소식/학과-공지/ | WP | 확인 | 2026-10 (제목 기준) | 보조: `/학과-소식/채용-공지/` |
| 사회과학대학 | 사회복지학부 | mysoongsil.ssu.ac.kr | https://mysoongsil.ssu.ac.kr/공지사항-2/학부-공지사항/ | WP | 확인 | 2026-10 | |
| 사회과학대학 | 행정학부 | pubad.ssu.ac.kr | https://pubad.ssu.ac.kr/정보광장/학부-공지사항/ | WP | 확인 | 2026-09 | |
| 사회과학대학 | 정치외교학과 | politics.ssu.ac.kr | https://politics.ssu.ac.kr/학과공지/학부-공지사항/ | WP | 확인 | 2026-10 | |
| 사회과학대학 | 정보사회학과 | inso.ssu.ac.kr | http://inso.ssu.ac.kr/sub/sub04_01.php?boardid=notice&category=학과공지 | BID | 확인 | 2026-09 | |
| 사회과학대학 | 언론홍보학과 | masscom.ssu.ac.kr | https://masscom.ssu.ac.kr/공지사항/학부공지/ | WP | 확인 | 2026-10 (제목 기준) | 보조: `/menu3/실습공지/`, `/공지사항/공모전-취업/`, `/공지사항/학술-세미나-행사/` |
| 사회과학대학 | 평생교육학과 | lifelongedu.ssu.ac.kr | https://lifelongedu.ssu.ac.kr/학과사무실알림/공지사항/ | WP | 확인 | 2026-10 | |
| 경제통상대학 | 경제학과 | eco.ssu.ac.kr | https://eco.ssu.ac.kr/bbs/board.php?bo_table=notice | G5 | 확인 | 2026-2학기 (제목 기준) | |
| 경제통상대학 | 글로벌통상학과 | gtrade.ssu.ac.kr | https://gtrade.ssu.ac.kr/학부알림/공지사항/ | WP | 확인 | 2026-10 | 보조: `/외국인-유학생/유학생-공지사항/`, `/학부알림/m3sub3/`(Job & Internship) |
| 경제통상대학 | 국제무역학과 (선취업후진학) | itrans.ssu.ac.kr | https://itrans.ssu.ac.kr/community/공지사항/ | WP | 확인 | 2026-2학기 (제목 기준) | |
| 경제통상대학 | 금융경제학과 (선취업후진학) | ecofinance.ssu.ac.kr | https://ecofinance.ssu.ac.kr/board/notice | CI | 확인 | 2026-10-29 | |
| 경영대학 | 경영학부 | biz.ssu.ac.kr | https://biz.ssu.ac.kr/bbs/list.do?bId=BBS_03_NOTICE | BIZ | 확인 | 2026-10 | 보조: `bId=BBS_03_NEWS`(학부소식), `BBS_03_CONT`(공모전), `BBS_04_NOTICE`(학생게시판) |
| 경영대학 | 회계학과 | accounting.ssu.ac.kr | https://accounting.ssu.ac.kr/게시판/행정공지사항/ | WP | 확인 | 2026-10 | 보조: `/게시판/강의공지사항/`, `/게시판/취업공지사항/`, `/특성화-프로그램/특성화-공지사항/` |
| 경영대학 | 벤처중소기업학과 | ensb.ssu.ac.kr | https://ensb.ssu.ac.kr/학부알림/학부공지사항/ | WP | 확인 | 2026-09 | 보조: `/학부알림/모집-채용공고/` |
| 경영대학 | 금융학부 | finance.ssu.ac.kr | https://finance.ssu.ac.kr/게시판/행정공지사항/ | WP | 확인 | 2026-10 | |
| 경영대학 | 혁신경영학과 (계약학과) | innobiz.ssu.ac.kr | http://innobiz.ssu.ac.kr/학사안내/공지사항/ | WP | 확인 | 2026-10 | |
| 경영대학 | 벤처경영학과 (계약학과) | mgmt.ssu.ac.kr | https://mgmt.ssu.ac.kr/학사안내/공지사항/ | WP | 확인 | 2026-10 | 글이 1페이지 분량뿐 |
| 경영대학 | 복지경영학과 (계약학과) | bokjimgt.ssu.ac.kr | https://bokjimgt.ssu.ac.kr/학사안내/공지사항/ | WP | 확인 | 2026학년도 모집 공고 | 글이 1페이지 분량뿐, 대부분 모집 공고 |
| 경영대학 | 회계세무학과 (계약학과) | actx.ssu.ac.kr | https://actx.ssu.ac.kr/학사안내/m2sub1/ | WP | 확인 | 2026-07 | ssu.ac.kr 링크 `/m2sub1/`은 이 주소로 넘어감 |
| 공과대학 | 화학공학과 | chemeng.ssu.ac.kr | http://chemeng.ssu.ac.kr/sub/sub03_01.php?boardid=notice1 | BID | 확인 | 2026-10 | |
| 공과대학 | 신소재공학과 | materials.ssu.ac.kr | https://materials.ssu.ac.kr/bbs/board.php?tbl=bbs51 | TBL | 확인 | 2026-10 | 보조: `tbl=bbs53`(학과소식), `tbl=bbs73` |
| 공과대학 | 전기공학부 | ee.ssu.ac.kr | http://ee.ssu.ac.kr/sub/sub05_02.php?boardid=major | BID | 확인 | 2026-10 | **ssu.ac.kr 소개 페이지와 기존 앱이 쓰는 `sub05_01.php?boardid=notice`는 지금 "학부소식"(보도자료 성격)이다.** 학부공지는 `sub05_02.php` |
| 공과대학 | 기계공학부 | me.ssu.ac.kr | https://me.ssu.ac.kr/notice/notice01.php | ME | 확인 | 2026-10-27 | 보조: `notice03.php`(취업), `notice05.php`(학과소식) |
| 공과대학 | 산업·정보시스템공학과 | iise.ssu.ac.kr | https://iise.ssu.ac.kr/cummunity/notice/ | WP | 확인 | (날짜 표기 없음) | 주소 철자가 `cummunity` |
| 공과대학 | 건축학부 (건축학·건축공학·실내건축전공) | soar.ssu.ac.kr | https://soar.ssu.ac.kr/news/notice/ | WP | 확인 | 2026-2학기 | 세 전공 공용 게시판. ssu.ac.kr 소개 페이지에는 공지 링크 없음, 홈 메뉴에서 찾음 |
| IT대학 | 컴퓨터학부 | cse.ssu.ac.kr | https://cse.ssu.ac.kr/bbs/board.php?bo_table=notice | G5 | 확인 | 2026-10-26 | |
| IT대학 | 전자정보공학부 전자공학전공 | infocom.ssu.ac.kr | http://infocom.ssu.ac.kr/kor/notice/undergraduate.php | INFO | 확인 | 2026-10-29 | 두 전공 공용 게시판. `pNo=2` 동작 확인. 보조: `/kor/notice/employment.php`(취업) |
| IT대학 | 전자정보공학부 IT융합전공 | infocom.ssu.ac.kr | (위와 같음) | INFO | 확인 | | |
| IT대학 | 글로벌미디어학부 | media.ssu.ac.kr | 화면: https://media.ssu.ac.kr/board/notices · API: https://3-37-127-112.sslip.io/v1/board/?page=0&size=15&menuId=136 | NX-API1 | 확인(API) | 2026-10-07 | 화면 HTML에는 글이 없음. API 주소는 사이트 JS에 박혀 있는 AWS IP(sslip.io)라 바뀔 수 있음. 메뉴 목록: `/v1/menu/?departmentCode=GLOBAL_MEDIA` (136=학부 공지, 137=대학원 공지, 138=특강공지) |
| IT대학 | 소프트웨어학부 | sw.ssu.ac.kr | https://sw.ssu.ac.kr/bbs/board.php?bo_table=notice | G5 | 확인 | 2026-10-21 | |
| IT대학 | AI융합학부 | aix.ssu.ac.kr | https://aix.ssu.ac.kr/notice.html | NV | 확인 | 2026-10-08 | `?page=2` 동작 확인. `searchKey=ai/smart/graduate` 탭은 서버에서 무시되어 같은 목록이 나옴 |
| IT대학 | 디지털미디어학과 (재직자전형) | mediamba.ssu.ac.kr | 화면: https://mediamba.ssu.ac.kr/board/notice · API: https://api.mediamba.ssu.ac.kr/v1/board/?page=0&size=15&menuId=89 | NX-API1 | 확인(API) | 2026-10-21 | 글로벌미디어와 같은 솔루션. `/v1/menu/?departmentCode=MEDIA_MBA` |
| AI대학 | AI소프트웨어학부 | ai.ssu.ac.kr | https://ai.ssu.ac.kr/board/notice | NX-SSR | 확인 | 2026-10-21 | AI대학 사이트를 겸함. 넘김은 `pageNum`(직접 확인, `page`는 무시). 보조: `/board/etc` |
| AI대학 | 정보보호학과 (계약학과) | sec.ssu.ac.kr | https://sec.ssu.ac.kr/bbs/board.php?bo_table=notice | G5 | 확인 | 2026-10-15 | |
| (독립) | 차세대반도체학과 | semicon.disu.ac.kr → www.disu.ac.kr | https://www.disu.ac.kr/community/notice?cidx=42 | DISU | 확인 | 2026-10 | 반도체 혁신융합대학 사업단 통합 사이트. `cidx=42`가 숭실대 필터. ssu.ac.kr 링크(`semicon.disu.ac.kr/...?cidx=42`)는 302로 넘어가며 `cidx`가 빠져 전체 대학 글이 섞임 |
| (독립) | 베어드학부대학 | ssubaird.ssu.ac.kr | https://ssubaird.ssu.ac.kr/공지사항/ | WP | 확인 | (2건뿐) | 교양 영역 9개(인간과성서·SW와AI 등)는 ssu.ac.kr에 소개만 있고 별도 사이트·게시판 없음 |
| (독립) | 자유전공학부 | sls.ssu.ac.kr | https://sls.ssu.ac.kr/학부소식/공지사항/ | WP | 확인 | 2026-2학기 (제목 기준) | |

## 2. 대학원

### 2-1. 일반대학원·전문/특수대학원 본부

| 소속 | 단위명 | 도메인 | 공지 게시판 URL (1페이지) | 엔진 | 확인 | 최근 글 | 비고 |
|---|---|---|---|---|---|---|---|
| 대학원 | 일반대학원 | grad.ssu.ac.kr | https://grad.ssu.ac.kr/정보광장/공지사항/ | WP | 확인 | 2026-10-12 | 분류 필터 `?term_id=31`(국제교류·외국인) 등 |
| 대학원 | AI전문대학원 | aig.ssu.ac.kr | 화면: https://aig.ssu.ac.kr/board/notice · API: https://aig.ssu.ac.kr/api/board/content/list?pageNum=1&boardEnName=notice | NX-API2 | 확인(API) | 2026-10-15 | 31건/4쪽. 보조: `boardEnName=special_notice`(양식자료실) |
| 대학원 | 중소기업대학원 | small.ssu.ac.kr | 화면: https://small.ssu.ac.kr/board/notice · API: https://small.ssu.ac.kr/api/board/content/list?pageNum=1&boardEnName=notice | NX-API2 | 확인(API) | 2026-09-19 | 203건/21쪽 |
| 대학원 | 정보과학대학원 | itmba.ssu.ac.kr | https://itmba.ssu.ac.kr/공지사항/학사공지/ | WP | 확인 | 2026-10-23 | 보조: `/공지사항/논문자료공지/`, `/공지사항/행정자료/`, `/soongsil-koica/notice/` |
| 대학원 | 사회복지대학원 | sabok.ssu.ac.kr | https://sabok.ssu.ac.kr/게시판/m4sub1/ | WP | 확인 | 2026-10-28 | |
| 대학원 | 교육대학원 | edu.ssu.ac.kr | https://edu.ssu.ac.kr/정보광장/공지사항/ | WP | 확인 | 2026-10-27 | 보조: `/원우회/원우회-공지사항-2/` |
| 대학원 | 경영대학원 | mba.ssu.ac.kr | https://mba.ssu.ac.kr/경교학팀/공지사항/ | WP | 확인 | 2026-10-29 (제목 기준) | |
| 대학원 | 기독교학대학원 | sgcs.ssu.ac.kr | https://sgcs.ssu.ac.kr/기독교학숭실人/공지사항/ | WP | 확인 | 2026-10-16 | 보조: `/입학정보/입학-공지사항/` |
| 대학원 | 안전융합대학원 | grad.safety.ssu.ac.kr | http://grad.safety.ssu.ac.kr/bbs/board.php?bo_table=sub7_4 | G5 | 확인 | 2026-10-27 | 학사 안내. 소식·행사는 `bo_table=sub7_1`(확인). 메뉴에 `sub0_6`도 있으나 미확인 |
| 대학원 | 가상융합대학원 (메타버스·문화콘텐츠학과) | metaverse.ssu.ac.kr | https://metaverse.ssu.ac.kr/data/content.json (화면: /notice.html) | JSON | 확인(API) | 2026-09-29 | ssu.ac.kr 대학원 목록에는 없음. 글로벌미디어 공지에서 이름을 보고 찾음. 공지 3건뿐 |

ssu.ac.kr 대학원 페이지에 실린 대학원은 일반·AI전문·중소기업·정보과학·사회복지·교육·경영·기독교학·안전융합 9개다. 요청에 예로 든 "소프트웨어특성화대학원"은 지금 별도 대학원으로 없다. 일반대학원 학과 목록에 융합소프트웨어학과·소프트웨어학과가 있다. 법학전문대학원도 없다.

### 2-2. 학과 사이트 안의 대학원 공지 게시판 (일반대학원 학과)

| 소속 | 단위명 | 도메인 | 공지 게시판 URL (1페이지) | 엔진 | 확인 | 최근 글 | 비고 |
|---|---|---|---|---|---|---|---|
| 일반대학원 | 기독교학과 | docs.ssu.ac.kr | https://docs.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | 2026-03 | |
| 일반대학원 | 영어영문학과 | englan.ssu.ac.kr | https://englan.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | 2026-10 | |
| 일반대학원 | 불어불문학과 | france.ssu.ac.kr | https://france.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | 2025 | |
| 일반대학원 | 중어중문학과 | chilan.ssu.ac.kr | https://chilan.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | (1건뿐) | |
| 일반대학원 | 일어일문학과 | japanstu.ssu.ac.kr | https://japanstu.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | 2023 | 사실상 휴면 |
| 일반대학원 | 철학과 | philo.ssu.ac.kr | https://philo.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | 2026-10-22 | |
| 일반대학원 | 사학과 | history.ssu.ac.kr | https://history.ssu.ac.kr/대학원/대학원-공지/ | WP | 확인 | 2026-08 | 2건뿐 |
| 일반대학원 | 생명정보학과 (의생명시스템학부) | bioinfo.ssu.ac.kr | https://bioinfo.ssu.ac.kr/게시판/공지사항/?term_id=94 | WP | 확인 | 2026-09 | 학부 공지 게시판의 "대학원" 분류 필터. 보조: `/게시판/대학원-세미나/` |
| 일반대학원 | 법학과 | law.ssu.ac.kr | https://law.ssu.ac.kr/대학원/대학원-공지/ | WP | 확인 | 2026-10-21 | |
| 일반대학원 | 국제법무(글로벌법률학과) | lawyer.ssu.ac.kr | https://lawyer.ssu.ac.kr/대학원/대학원-공지/ | WP | 확인 | 2026-2학기 (제목 기준) | |
| 일반대학원 | 사회복지학과 | mysoongsil.ssu.ac.kr | https://mysoongsil.ssu.ac.kr/대학원/대학원-공지사항/ | WP | 확인 | 2026-10-21 | |
| 일반대학원 | 행정학과 | pubad.ssu.ac.kr | https://pubad.ssu.ac.kr/정보광장/대학원-공지사항/ | WP | 확인 | 2026-09 | |
| 일반대학원 | 정치외교학과 | politics.ssu.ac.kr | https://politics.ssu.ac.kr/공지사항/ | WP | 확인 | 2026-10-20 | 주소는 `/공지사항/`이지만 제목이 "대학원 공지사항" |
| 일반대학원 | 평생교육학과 | lifelongedu.ssu.ac.kr | https://lifelongedu.ssu.ac.kr/대학원/공지사항/ | WP | 확인 | 2026-08 | |
| 일반대학원 | 경제학과 | eco.ssu.ac.kr | https://eco.ssu.ac.kr/bbs/board.php?bo_table=gra_notice | G5 | 확인 | 2026-09 | |
| 일반대학원 | 무역학과 (글로벌통상학과) | gtrade.ssu.ac.kr | https://gtrade.ssu.ac.kr/대학원/대학원-공지사항/ | WP | 확인 | 2026-08 | |
| 일반대학원 | 경영학과 | biz.ssu.ac.kr | https://biz.ssu.ac.kr/bbs/list.do?bId=BBS_05_NOTICE | BIZ | 확인 | 2026-10 | |
| 일반대학원 | 회계학과 | accounting.ssu.ac.kr | https://accounting.ssu.ac.kr/일반대학원/게시판/ | WP | 확인 | 2024 | 사실상 휴면 |
| 일반대학원 | 벤처중소기업학과 | ensb.ssu.ac.kr | https://ensb.ssu.ac.kr/대학원알림/대학원공지사항/ | WP | 확인 | 2026-09 | |
| 일반대학원 | 금융학과·금융기술융합학과 | finance.ssu.ac.kr | https://finance.ssu.ac.kr/대학원/대학원-공지사항/ | WP | 확인 | 2026-10-21 | |
| 일반대학원 | 화학공학과 | chemeng.ssu.ac.kr | http://chemeng.ssu.ac.kr/sub/sub03_02.php?boardid=notice2 | BID | 확인 | 2025 | |
| 일반대학원 | 신소재공학과 | materials.ssu.ac.kr | https://materials.ssu.ac.kr/bbs/board.php?tbl=bbs52 | TBL | 확인 | 2026-10 | |
| 일반대학원 | 전기공학과 | ee.ssu.ac.kr | http://ee.ssu.ac.kr/sub/sub04_03.php?boardid=academy | BID | 확인 | 2025 | 메뉴 이름 "대학원게시판" |
| 일반대학원 | 전자공학과·정보통신공학과 (전자정보공학부) | infocom.ssu.ac.kr | http://infocom.ssu.ac.kr/kor/notice/graduateSchool.php | INFO | 확인 | 2026-10-27 | `code=graduate` |
| 일반대학원 | 컴퓨터학과 | cse.ssu.ac.kr | https://cse.ssu.ac.kr/bbs/board.php?bo_table=gra_notice | G5 | 확인 | 2026-10-27 | |
| 일반대학원 | 소프트웨어학과 | sw.ssu.ac.kr | https://sw.ssu.ac.kr/bbs/board.php?bo_table=gra_notice | G5 | 확인 | 2026-10-27 | |
| 일반대학원 | 정보보호 (AI융합보안학과 추정) | sec.ssu.ac.kr | https://sec.ssu.ac.kr/bbs/board.php?bo_table=gra_notice | G5 | 확인 | 2023 | 사실상 휴면 |
| 일반대학원 | 미디어학과 (글로벌미디어학부) | media.ssu.ac.kr | 화면: https://media.ssu.ac.kr/board/graduate-school-notices · API: `…/v1/board/?page=0&size=15&menuId=137` | NX-API1 | 확인(API) | 2026-10-27 | 특강공지는 `menuId=138`(최근 2025-06) |
| 일반대학원 | 디지털미디어학과 대학원 | mediamba.ssu.ac.kr | (자체 게시판 없음, 메뉴가 grad.ssu.ac.kr 공지로 연결) | - | 확인 | | |

## 3. 학교 공통

| 소속 | 단위명 | 도메인 | 공지 게시판 URL (1페이지) | 엔진 | 확인 | 최근 글 | 비고 |
|---|---|---|---|---|---|---|---|
| 본부 | 학교 공지 (SSU:catch) | scatch.ssu.ac.kr | https://scatch.ssu.ac.kr/공지사항/ | WP (자체 변형) | 확인 | 2026-10-29 | 넘김 `/공지사항/page/N/`, 분류 `?f&category=<분류>&keyword=<검색어>`. `page/2/?f&category=장학` 동작 확인. 분류: 학사, 장학, 국제교류, 외국인유학생, 채용, 비교과·행사, 교원채용, 교직, 봉사, 기타. **장학·학사 공지는 별도 게시판이 아니라 이 게시판의 분류다** |
| 본부 | 기숙사 (레지던스홀) | ssudorm.ssu.ac.kr:444 | https://ssudorm.ssu.ac.kr:444/SShostel/mall_main.php?viewform=B0001_noticeboard_list&board_no=1 | DORM | 확인 | 2026-10-01 | **`board_no=1`이 필요하다.** 기존 앱 주소(`board_type=&next=`, board_no 없음)는 "사생전용 게시판입니다" 알림 뒤 메인으로 튕긴다. EUC-KR. 보조: `board_no=2`(각종서식) |
| 본부 | 입학처 통합공지 | iphak.ssu.ac.kr | https://iphak.ssu.ac.kr/board/notice_list.asp?page=1&srchoption=&keyword=&flag=1&page_no=1_1_1 | ASP | 확인 | 2026-04 | flag 1=수시, 2=정시, 3=편입학, 4=재외국민, 5=시간제, 7=외국인, 8=예비숭실인 |
| 본부 | 중앙도서관 | oasis.ssu.ac.kr | API: https://oasis.ssu.ac.kr/pyxis-api/1/bulletin-boards/1/bulletins?offset=0&max=10 | PYX | 확인(API) | 2026-10 | 전체 1,919건. 사람이 보는 화면 주소는 미확인 |
| 본부 | 학생상담센터 | counsel.ssu.ac.kr | https://counsel.ssu.ac.kr/알림마당/공지사항/ | WP | 확인 | 2026-10-13 | |
| 본부 | 교수학습혁신센터 | ctl.ssu.ac.kr | https://ctl.ssu.ac.kr/공지사항/ | WP | 확인 | 2026-09-23 | |
| 본부 | 인권센터 | humanrights.ssu.ac.kr | https://humanrights.ssu.ac.kr/알림마당/공지사항/ | WP | 확인 | 2026-09-21 | |
| 본부 | 진로취업센터 (졸업생 프로그램 공지) | job.ssu.ac.kr | http://job.ssu.ac.kr/service/careerProgram/careerGraduateNoticeList.do | Java .do | 부분 확인 | 2026-10-29 | 날짜는 보이나 글 링크 구조는 미확인. 넘김 `currentPageNo`, 검색 `searchType`/`searchValue`. 재학생용 일반 공지 게시판은 홈에서 못 찾음 |
| 본부 | 국제처 (단기 프로그램) | study.ssu.ac.kr | https://study.ssu.ac.kr/community/notice_list.do | Java .do | 미확인 | | 열리지만 목록을 해석하지 못함 |

## 게시판을 못 찾았거나 확인에 실패한 곳

- 문예창작전공 대학원(문예창작학과): `/대학원/게시판/`은 "교육목표" 페이지라 공지가 아님. 대학원 공지 게시판 없음
- 언론홍보학과·물리학과·수학과·화학과·국어국문학과·독어독문학과·정보사회학과·산업정보시스템공학과·기계공학부·정보통계보험수리학과: 학과 사이트에 대학원 공지 게시판 없음 (대학원생은 grad.ssu.ac.kr 공지를 보면 됨)
- AI융합학부 대학원: 홈의 `searchKey=graduate` 탭이 서버에서 동작하지 않아 학부 목록과 같음
- 베어드학부대학 교양 영역 9개(인간과성서, 글로벌시민의식, 글로벌소통과언어, 비판적사고와표현, 인문적상상력과소통, 창의적사고와혁신, 컴퓨팅적사고, SW와AI, 한반도평화와통일): 별도 사이트·게시판 없음
- 단과대학 단위 게시판: 12개 단과대학 모두 ssu.ac.kr 소개 페이지에 홈페이지 링크가 없다(베어드학부대학 제외). `it.ssu.ac.kr`, `eng.ssu.ac.kr`, `inmun.ssu.ac.kr` 등 추측 주소도 응답 없음. AI대학만 ai.ssu.ac.kr이 학부 사이트를 겸함
- 미확인으로 남은 것: 국제처 목록, 진로취업센터 글 링크, 도서관 화면 주소, 안전융합대학원 `sub0_6`

## 2022년 이후 신설·통폐합·명칭 변경 (이번 조사에서 직접 본 근거만)

| 변동 | 내용 | 근거 |
|---|---|---|
| 신설 (2025) | **AI대학** 설립, **AI소프트웨어학부** 통합 신설, **AI전문대학원** 설립 | ai.ssu.ac.kr 연혁 "2025. AI대학 설립, AI소프트웨어학부 통합, AI전문대학원 설립" |
| 소속 이동 | **정보보호학과(계약학과)** 가 AI대학 소속으로 표기됨 (IT대학 소개문에는 아직 IT대학 소속으로 남아 있음) | ssu.ac.kr AI대학·IT대학 페이지 |
| 통합 진행 중 | **AI융합학부**(IT대학)는 남아 있으나 공지에 "AI소프트웨어학부 소속변경(전과) 신청 가이드", "AI융합학부만 해당" 같은 안내가 있어 AI소프트웨어학부로 옮겨 가는 중으로 보임. 2021년 스마트시스템소프트웨어학과에서 이름을 바꿈 | aix.ssu.ac.kr 공지, ai.ssu.ac.kr 연혁 |
| 명칭 변경 | **미디어경영학과 → 디지털미디어학과** (재직자전형) | ssu.ac.kr 주소 이름은 `미디어경영학과-재직자전형`, 표시 이름은 디지털미디어학과 |
| 명칭 변경 | **베어드교양대학 → 베어드학부대학** | ssu.ac.kr 주소 이름은 `베어드교양대학`, 표시 이름은 베어드학부대학 |
| 명칭 변경 (시기 미확인) | 학부 **국제무역학과 → 글로벌통상학과**(gtrade). "국제무역학과"라는 이름은 지금 선취업후진학 학과(itrans)가 씀 | 경제통상대학 소개문, 기존 앱 주소 `pre.ssu.ac.kr/web/itrade` |
| 신설 (시기 미확인) | **금융경제학과·국제무역학과** (선취업후진학), **혁신경영·벤처경영·복지경영·회계세무학과** (계약학과) | 경제통상·경영대학 페이지 |
| 신설 | **자유전공학부** ("신설된 학부"라고만 표기, 연도 미확인) | ssu.ac.kr 자유전공학부 페이지 |
| 신설 (2021-11) | **차세대반도체학과** — 입학정원 없는 다전공 학과, 첨단분야 혁신융합대학 사업 | ssu.ac.kr 차세대반도체학과 페이지 |
| 신설 | **가상융합대학원** (메타버스·문화콘텐츠학과) — ssu.ac.kr 대학원 목록에는 아직 없음 | metaverse.ssu.ac.kr |
| 통폐합 (추정) | 공과대학 목록에 **유기신소재·파이버공학과가 없고 신소재공학과만** 있음. materials.ssu.ac.kr 소개에 파이버 소재가 함께 나오고 "신소재/친환경화학소재" 행사가 있어 통합된 것으로 보이나, 통합 시기와 공식 근거는 미확인 | ssu.ac.kr 공과대학 페이지 |

## 기존 Notissu 코드와 달라진 점 (참고)

- Liferay(`p_p_id=EXT_BBS`) 게시판은 이번에 확인한 곳 중 **한 곳도 남아 있지 않다.** 인문·자연·법·사회·경영 계열 대부분이 WP 공통 테마(`/page/N/?keyword=`)로 옮겨 갔다.
- `pre.ssu.ac.kr/web/...` 주소는 모두 학과별 도메인으로 바뀌었다 (예: 철학과 → philo.ssu.ac.kr, 정치외교 → politics.ssu.ac.kr, 국제무역 → gtrade/itrans).
- 컴퓨터학부는 `03_sub/01_sub.htm`에서 그누보드(`bo_table=notice`)로, 글로벌미디어학부는 `sub.php?code=…`에서 Next.js+API로, 영어영문·법학·사회복지 등은 경로가 바뀌었다.
- 전기공학부 `sub05_01.php`는 지금 "학부소식"이다(학부공지는 `sub05_02.php?boardid=major`).
- 기숙사 목록에는 `board_no=1`을 붙여야 한다.
- 스마트시스템소프트웨어학과(`smartsw.ssu.ac.kr`)와 글쓰기 관련 `writing.ssu.ac.kr`은 이번 조직표에 없다.
