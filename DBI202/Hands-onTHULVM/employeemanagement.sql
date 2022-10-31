﻿CREATE DATABASE employeemanagement
use employeemanagement
drop table Employee

create table Employee (
FName varchar(15) not null,
MInit char(1),
LName varchar(15) not null,
SSN char(9) not null,
BDate smalldatetime null,
Address varchar(30),
Sex char(1),
Salary decimal(18,2),
SuperSSN char(9),
DNo int not null,
HireDate smalldatetime null,
constraint PK_Employee primary key (SSN),
constraint FK_Employee_Employee foreign key (SuperSSN) references Employee (SSN),
)
drop table Department
create table Department (
DName varchar(15) not null,
DNumber int not null,
MgrSSN char(9) not null,
MgrStartDate smalldatetime,
nbrEmployees int,
constraint PK_Department primary key (DNumber),
constraint FK_Department_Employee foreign key (MgrSSN) references Employee (SSN)
on delete cascade on update cascade
)
alter table Employee
add constraint FK_Employee_Department foreign key (DNo) references Department (DNumber)
create table Project (
PName varchar(15) not null,
PNumber int not null,
PLocation varchar(15),
DNumber int not null,
constraint PK_Project primary key (PNumber),
constraint FK_Project_Department foreign key (DNumber) references Department (DNumber)
)
create table DeptLocations (
DNumber int not null,
DLocation varchar(15) not null,
constraint PK_Dept_Locations primary key (DNumber,DLocation),
constraint FK_Dept_Locations_Department foreign key (DNumber) references Department (DNumber)
)
create table Dependent (
ESSN char(9) not null,
DependentName varchar(15) not null,
Sex char(1),
BDate smalldatetime null,
Relationship varchar(8),
constraint PK_Dependent primary key (ESSN,DependentName),
constraint FK_Dependent_Employee foreign key (ESSN) references Employee (SSN)
)
create table WorksOn (
ESSN char(9) not null,
PNo int not null,
hours decimal(18,1) not null,
constraint PK_WorksOn primary key (ESSN,PNo),
constraint FK_WorksOn_Employee foreign key (ESSN) references Employee (SSN),
constraint FK_WorksOn_Project foreign key (PNo) references Project (PNumber)
)

select * from WorksOn








--1
create trigger age18
on Employee
after insert, update
as
if exists (
select *
from Inserted
where dateadd(year,18,BDate) > getdate() )
begin
raiserror('Constraint Violation: The age of an employee
must be greater than 18', 1, 1)
rollback
end
--2.
create trigger supervisorAge
on Employee
after insert, update
as
if exists (
select *
from Inserted I,
Employee E
where ( I.SuperSSN = E.SSN and I.BDate < E.BDate )
or ( E.SuperSSN = I.SSN and E.BDate < I.BDate ) )
begin
raiserror( 'Constraint Violation:
The age of an employee must be less than
the age of his/her supervisor', 1, 1)
rollback
end
--3.
create trigger supervisorSalary
on Employee
after insert, update
as
if exists (
select *
from Inserted I,
Employee E
where ( I.SuperSSN = E.SSN and I.Salary > E.Salary )
or ( E.SuperSSN = I.SSN and E.Salary > I.Salary ) )
begin
raiserror('Constraint Violation:
The salary of an employee cannot be greater than
the salary of his/her supervisor', 1, 1)
rollback
end

--4.
alter table Employee
add constraint UN_Employee_SSN_DNo
unique( SSN, DNO )
alter table Department
add constraint FK_Employee_SSN_DNo
foreign key( MgrSSN, DNumber )
references Employee( SSN, DNo )--5.alter table Project
add constraint FK_Project_DeptLocations
foreign key( DNumber, PLocation )
references DeptLocations( DNumber, DLocation )

--6.
alter table Employee
add constraint HireDate_BDate
check( HireDate > BDate )--7.create trigger hireSuperv
on Employee
after insert, update
as
if exists (
select *
from Inserted I,
Employee E
where ( I.SuperSSN = E.SSN and datediff(year, E.HireDate, I.HireDate) < 1
)
or ( E.SuperSSN = I.SSN and datediff(year, I.HireDate, E.HireDate) < 1
) )
begin
raiserror('Constraint Violation:
A supervisor must be hired at least 1 year before
every employee s/he supervises', 1, 1)
rollback
end

--8.
create trigger derived_Department_NbrEmployees_Employee
on Employee
after insert, update, delete
as
begin
update Department
set NbrEmployees = NbrEmployees +
( select count(*) from Inserted I where DNumber=I.DNo ) -
( select count(*) from Deleted D where DNumber=D.DNo )
where DNumber in ( select DNo from Inserted )
or DNumber in ( select DNo from Deleted )
end

create trigger derived_Department_NbrEmployees_Department
on Department
after insert, update
as
if exists ( select *
from Inserted
where NbrEmployees <> ( select count(*)
from Employee E
where E.DNo = DNumber ) )
begin
raiserror('Constraint Violation:
The attribute Department.NbrEmployees is a derived
attribute from Employee.DNo', 1, 1)
rollback
end
--9.
create trigger empNbrProj
on WorksOn
after insert, update
as
if exists (
select *
from WorksOn W
group by W.ESSN
having count(*) > 4 )
begin
raiserror('Constraint Violation: An employee works at
most in 4 projects', 1, 1)
rollback
end
--10.
create trigger workson_30_50
on WorksOn
after insert, update, delete
as
if exists ( select *
from WorksOn
group by ESSN
having ( sum(Hours) < 30 )
or ( sum(Hours) > 50 ) )
begin
raiserror('Constraint Violation: An employee works at
least 30 h/week and at most 50 h/week on all its projects', 1, 1)
rollback
end
--11.
create trigger worksonLess10h
on WorksOn
after insert, update
as
if exists ( select *
from WorksOn
where Hours < 10
group by PNo
having count(*) > 2 )
begin
raiserror('Constraint Violation: A project can have at
most 2 employees working on the project less than 10 hours', 1, 1)
rollback end
--12.
create trigger worksonLess5h_WorksOn
on WorksOn
after insert, update
as
if exists ( select *
from Inserted
where Hours < 5
and ESSN not in (
select MgrSSN
from Department
where MgrSSN is not null ) )
begin
raiserror('Constraint Violation: Only department managers
can work less than 5 hours on a project', 1, 1)
rollback
end
create trigger worksonLess5h_Department
on Department
after update, delete
as
if exists ( select *
from Deleted
where MgrSSN not in (
select MgrSSN
from Department )
and MgrSSN in (
select ESSN
from WorksOn
where Hours < 5 ) )
begin
raiserror('Constraint Violation: Only department managers
can work less than 5 hours on a project', 1, 1)
rollback
end

--13.
create trigger workson10h_WorksOn
on WorksOn
after insert, update
as
if exists ( select *
from Inserted
where Hours < 10
and ESSN not in (
select SuperSSN
from Employee
where SuperSSN is not null ) )
begin
raiserror('Constraint Violation: Employees that are not supervisors
must work at least 10 hours on every project they work', 1, 1)
rollback
end
create trigger workson10h_Employee
on Employee
after update, delete
as
if exists ( select *from Deleted
where SuperSSN not in (
select SuperSSN
from Employee
where SuperSSN is not null )
and SuperSSN in (
select ESSN
from WorksOn
where Hours < 10 ) )
begin
raiserror('Constraint Violation: Employees that are not supervisors
must work at least 10 hours on every project they work', 1, 1)
rollback
end