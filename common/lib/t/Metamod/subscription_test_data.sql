--
-- PostgreSQL database dump
--

-- Started on 2010-09-07 13:05:37 CEST

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

--
-- TOC entry 1782 (class 0 OID 0)
-- Dependencies: 1481
-- Name: dataset_ds_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dataset_ds_id_seq', 5, true);


--
-- TOC entry 1783 (class 0 OID 0)
-- Dependencies: 1483
-- Name: infods_i_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('infods_i_id_seq', 1, false);


--
-- TOC entry 1784 (class 0 OID 0)
-- Dependencies: 1485
-- Name: infouds_i_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('infouds_i_id_seq', 6, true);


--
-- TOC entry 1785 (class 0 OID 0)
-- Dependencies: 1479
-- Name: usertable_u_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('usertable_u_id_seq', 4, true);


--
-- TOC entry 1775 (class 0 OID 19438)
-- Dependencies: 1480
-- Data for Name: usertable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY usertable (u_id, a_id, u_name, u_loginname, u_email, u_password, u_institution, u_telephone) FROM stdin;
1	TEST	tester	metamod1	metamod@met.no	\N	\N	\N
2	TEST	owner	metamod2	metamod@met.no	\N	\N	\N
3	OTHER	other	metamod3	metamod@met.no	\N	\N	\N
4	TEST	tester2	metamod4	metamod@met.no	\N	\N	\N
\.

--
-- TOC entry 1776 (class 0 OID 19449)
-- Dependencies: 1482
-- Data for Name: dataset; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dataset (ds_id, u_id, a_id, ds_name) FROM stdin;
1	2	TEST	hirlam12
2	3	OTHER	itp04
5	2	TEST	itp05
\.


--
-- TOC entry 1777 (class 0 OID 19467)
-- Dependencies: 1484
-- Data for Name: infods; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY infods (i_id, ds_id, i_type, i_content) FROM stdin;
\.


--
-- TOC entry 1778 (class 0 OID 19483)
-- Dependencies: 1486
-- Data for Name: infouds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY infouds (i_id, u_id, ds_id, i_type, i_content) FROM stdin;
1	1	1	SUBSCRIPTION_XML	<subscription type="email" xmlns="http://www.met.no/schema/metamod/subscription">\n<param name="address" value="metamod@met.no" />\n</subscription>
6	4	1	SUBSCRIPTION_XML	<subscription type="sms" xmlns="http://www.met.no/schema/metamod/subscription">\n<param name="server" value="ftp2.met.no" />\n<param name="username" value="metamod2" />\n<param name="password" value="secret2" />\n</subscription>
2	2	1	SUBSCRIPTION_XML	<subscription type="sms" xmlns="http://www.met.no/schema/metamod/subscription">\n<param name="server" value="ftp.met.no" />\n<param name="username" value="metamod" />\n<param name="password" value="secret" />\n</subscription>
\.





-- Completed on 2010-09-07 13:05:37 CEST

--
-- PostgreSQL database dump complete
--

