
# 📘 Database Normalization & Normal Forms

Database normalization is a process used in relational database design to minimize redundancy and ensure data integrity. It involves organizing data into tables following a set of rules called **normal forms (NF)**.

This document covers the different normal forms, from 1NF to 6NF.

---

## 🔹 1NF – First Normal Form

### ✅ Rules:
- Each column must contain **atomic (indivisible)** values.
- Each row must be **unique**.
- No repeating groups or arrays in a single column.

### 📌 Example:
```text
✅ Good (1NF):
StudentID | Name   | Course
----------|--------|--------
1         | Alice  | Math
1         | Alice  | Physics

❌ Bad:
StudentID | Name   | Courses
----------|--------|--------------
1         | Alice  | Math, Physics
```

---

## 🔹 2NF – Second Normal Form

### ✅ Rules:
- Must satisfy **1NF**.
- No **partial dependency**: every non-key attribute must depend on the **whole primary key**.

### 📌 Example:
If a table has a composite key (e.g., `StudentID, CourseID`), then attributes like `StudentName` should not depend on just `StudentID`.

---

## 🔹 3NF – Third Normal Form

### ✅ Rules:
- Must satisfy **2NF**.
- No **transitive dependency**: non-key attributes should not depend on other non-key attributes.

### 📌 Example:
```text
❌ Bad:
EmployeeID | Name  | DepartmentID | DepartmentName

DepartmentName depends on DepartmentID, not on EmployeeID.

✅ Good:
1. Employees: EmployeeID, Name, DepartmentID
2. Departments: DepartmentID, DepartmentName
```

---

## 🔹 BCNF – Boyce-Codd Normal Form

### ✅ Rules:
- Must satisfy **3NF**.
- For every dependency X → Y, **X should be a super key**.

More strict than 3NF. Used when 3NF still has anomalies.

---

## 🔹 4NF – Fourth Normal Form

### ✅ Rules:
- Must satisfy **BCNF**.
- No table should contain **more than one independent multi-valued dependency**.

### 📌 Example:
```text
❌ Bad:
PersonID | PhoneNumber | Email
---------|-------------|------------------
1        | 1234567890  | a@example.com
1        | 9876543210  | b@example.com

✅ Good:
1. Phones: PersonID, PhoneNumber
2. Emails: PersonID, Email
```

---

## 🔹 5NF – Fifth Normal Form (Project-Join Normal Form)

### ✅ Rules:
- Must satisfy **4NF**.
- No **join dependency** that causes data loss during decomposition.
- Ensures correct reconstruction of original data from decomposed tables.

---

## 🔹 6NF – Sixth Normal Form

- Used in **temporal databases**.
- Deals with **non-trivial join dependencies** and time-based data.
- Not commonly required in general business applications.

---

## 📌 Summary Table

| Normal Form | Key Idea                                  |
|-------------|--------------------------------------------|
| 1NF         | Atomic values, no repeating groups         |
| 2NF         | No partial dependency                      |
| 3NF         | No transitive dependency                   |
| BCNF        | Every determinant is a super key           |
| 4NF         | No multi-valued dependencies               |
| 5NF         | No join dependency anomalies               |
| 6NF         | Used in time-sensitive data scenarios      |

---

## ✅ Benefits of Normalization

- Reduces **data redundancy**
- Improves **data integrity**
- Makes maintenance easier
- Improves **scalability** and **performance** (in well-indexed databases)

---

> ⚠️ Note: In practice, normalization is often balanced with performance considerations. Sometimes partial denormalization is used for speed in large-scale systems.
