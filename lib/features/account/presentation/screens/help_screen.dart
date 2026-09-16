import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HelpEntry {
  const HelpEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Odpowiedzi opisują faktyczne działanie aplikacji — przy zmianie funkcji
/// zaktualizuj też ten tekst.
const kHelpEntries = [
  HelpEntry(
    question: 'Czy aplikacja działa bez internetu?',
    answer:
        'Tak. Treningi, plany i własne ćwiczenia zapisują się najpierw na '
        'telefonie, więc możesz trenować offline. Gdy wróci połączenie, '
        'zmiany wyślą się na serwer automatycznie. Feed, kudosy, komentarze '
        'i profile innych osób wymagają internetu — bez sieci feed pokazuje '
        'ostatnio zapisaną stronę.',
  ),
  HelpEntry(
    question: 'Co oznacza ikonka synchronizacji w rogu ekranu?',
    answer:
        'Kręcąca się ikona — trwa wysyłanie lub pobieranie danych. Zielona '
        'chmurka — wszystko jest zapisane na serwerze. Pomarańczowa kropka — '
        'zmiany czekają na wysłanie (np. brak internetu). Czerwona — serwer '
        'odrzucił część zmian. Stuknij ikonę, aby zobaczyć szczegóły '
        'i użyć przycisku „Synchronizuj teraz”.',
  ),
  HelpEntry(
    question: 'Jak udostępnić trening w feedzie?',
    answer:
        'Po zakończeniu treningu na ekranie podsumowania wybierz „Udostępnij '
        'na profilu”. Możesz to zrobić także później: otwórz trening '
        'w historii i stuknij ikonę udostępniania w nagłówku — tam również '
        'schowasz trening z profilu. Udostępnione treningi widzą w zakładce '
        'Aktywność osoby, które Cię obserwują.',
  ),
  HelpEntry(
    question: 'Jak działają kudosy i komentarze?',
    answer:
        'Pod treningiem innej osoby stuknij kudosa, aby docenić jej pracę '
        '(własnym treningom nie można dawać kudosów). W szczegółach treningu '
        'możesz dodać komentarz do 500 znaków. Aby usunąć komentarz, '
        'przytrzymaj go — opcja jest dostępna, gdy masz do tego uprawnienia.',
  ),
  HelpEntry(
    question: 'Czy mogę edytować lub usunąć zakończony trening?',
    answer:
        'Tak. Otwórz trening w historii i wybierz menu (trzy kropki): '
        '„Edytuj trening”, „Powtórz trening” albo „Usuń trening”. '
        'Działa to także bez internetu — zmiany wyślą się po powrocie sieci. '
        'Usunięcie jest nieodwracalne i usuwa też kudosy oraz komentarze. '
        'Jeśli chcesz tylko ukryć trening przed innymi, schowaj go z profilu.',
  ),
  HelpEntry(
    question: 'Co się stanie z niewysłanymi zmianami po wylogowaniu?',
    answer:
        'Zostaną na tym telefonie i wyślą się, gdy znów zalogujesz się na to '
        'samo konto. Przed wylogowaniem aplikacja ostrzega, jeśli takie '
        'zmiany istnieją.',
  ),
  HelpEntry(
    question: 'Jak zmienić hasło?',
    answer:
        'Wejdź w Profil → Ustawienia → Zmiana hasła. Podaj obecne hasło '
        'i nowe (co najmniej 8 znaków, wielka litera i cyfra). Zmiana wymaga '
        'internetu. Po zmianie zostaniesz wylogowany na pozostałych '
        'urządzeniach, a na tym telefonie sesja pozostanie aktywna.',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.entries = kHelpEntries});

  final List<HelpEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('POMOC')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          itemCount: entries.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Najczęstsze pytania',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }
            final entry = entries[index - 1];
            return Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  iconColor: AppColors.textSecondary,
                  collapsedIconColor: AppColors.textMuted,
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    entry.question,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    Text(
                      entry.answer,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
