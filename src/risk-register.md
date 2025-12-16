**Risk Register**

| ID | Description | Probability | Priority | Impact | Mitigation strategy |
|----|-------------|-------------|----------|--------|---------------------|
| 1  | Витік даних з БД | low | high | critical | Шифрування даних і трафіку, надавати доступ лише до необхідних ресурсів |
| 2  | Компроментація адмінського акаунта | medium | high | critical | Налаштувати MFA та аларм на повторні спроби невдалого входу |
| 3  | Помилкове перевищення бюджету | high | medium | medium | Налаштувати billing alarm, який спрацьовує, якщо наявна сума близька до максимальної |
| 4  | DDoS/DoS атака | low | medium | medium | Моніторити вхідний трафік, обмежити кількість одночасних запитів |
| 5  | Недоступність AWS | low | low | high | Розмістити ресурси у різних зонах |
| 6  | Завантаження шкідливого ПЗ з файлом | medium | high | high | Налаштувати GuardDuty на сканування на шкідливе ПЗ |
| 7  | Недоступність сервісу через перенавантаження (не пов'язано зі зловмисними діями) | medium | medium | medium | Обмежити кількість одночасних запитів, налаштувати аларм на навантаження CPU |
| 8  | Втрата ключів шифрування | low | high | critical | Налаштувати період очікування видалення ключів |

**Threat model**

За схемою STRIDE

**_Spoofing:_**

Зловмисник викрадає дані для входу адміна і видає себе за легітимного користувача. Mitigation: MFA, failed login alarm

**_Tampering:_**

Зловмисник отримує доступ до S3 бакета з даними користувачів та модифікує записи

Mitigation: GuardDuty S3 protection, CloudTrail data events

**_Repudiation:_**

Адмін видаляє запис із БД і заперечує це

Mitigation: audit logging

**_Information disclosure:_**

Витік конфіденційних даних через неправильні налаштування бакета

Mitigation: encryption (KMS)

**_Denial of service:_**

Зловмисник видаляє ключі шифрування

Mitigation: дозвіл видаляти ключі лише у адміна, період очікування перед остаточним видаленням

**_Elevation of privilege:_**

Спроба розширити ІАМ політики

Mitigation: least privilege принцип, management logging, GuardDuty privilege escalation detection
Rendered
Risk Register

