create or replace package csf_own.pk_valida_ambiente_ct is

-------------------------------------------------------------------------------------------------------
--
-- Especifica��o do pacote da API para ler os Conhecimentos de Transportes com DM_ST_PROC = 0 (N�o validada)
-- e chamar os procedimentos para validar os dados
--
-- Em 17/02/2021   - Karina de Paula
-- Redmine #76274  - Ajuste para contemplar anula��o de CTe
-- Rotina Alterada - pkb_ler_ct_int_ws => Inclu�do verificacao da qtd pendente e qtd com erro para as rotinas do cte
-- Liberado        - Release_2.9.7, Patch_2.9.6.2 e Patch_2.9.5.5
--
-- Em 15/02/2021   - Karina de Paula
-- Redmine #76105  - Ajuste no WS - Emiss�o de CTe
-- Rotina Alterada - pkb_ler_ct_int_ws => Inclu�dos os dm_st_proc (5, 10, 11, 12, 13, 15, 16, 99) na verifica��o de retorno de erro (vn_qtde)
--                   Esse retorno que define o status do lote para "Processado com erro" (4).
-- Liberado        - Release_2.9.7, Patch_2.9.6.2 e Patch_2.9.5.5
--
-- Em 05/02/2021   - Karina de Paula
-- Redmine #75876  - Cancelamento rejeitado fica sendo reenviado
-- Rotina Alterada - pkb_ler_Conhec_Transp/pkb_ler_Conhec_Transp_Canc/pkb_ler_ct_int_ws => Incluida a verificacao do dominio dm_canc_servico para que os conhecimentos que
--                   entraram em conting�ncia via Webservice e se o cancelamento foi tentado via portal seta o campo 
--                   DM_CANC_SERVICO para 1 (um) para evitar loop de tentativa de cancelamento
-- Liberado        - Release_2.9.7, Patch_2.9.6.2 e Patch_2.9.5.5
--
-- Em 28/01/2021   - Karina de Paula
-- Redmine #75607  - Ajustes na rotina de integra��o do CTe
-- Rotina Alterada - pkb_ler_Conhec_Transp => Inclu�do novo par�metro "en_integra", sendo o valor igual a "0" sa�ra da integra��o
--                 - pkb_ler_Ctcompltado_Imp / pkb_ler_Conhec_Transp_Imp => Campo dm_inf_imp recebe valor default "0" se estiver nulo
-- Liberado        - Release_2.9.7, Patch_2.9.6.2 e Patch_2.9.5.5
--
-- Em 19/01/2021   - Karina de Paula
-- Redmine #75107  - Tabelas que envolvem o processo de CCE conhec_transp_CCE ou evento_cte_cce/evento_cte e tamb�m r_loteintws_ct
-- Rotina Criada   - pkb_ler_conhec_transp_cce / pkb_vld_conhec_transp_cce
-- Rotina Alterada - pkb_integracao/pkb_integracao_mo => Incluida a chamada da pkb_ler_conhec_transp_cce e organizada as chamadas duplicadas
--                 - pkb_ler_ct_int_ws => Incluida a chamada da pkb_vld_conhec_transp_cce
-- Liberado        - Patch_2.9.6.1
--
-- Em 14/01/2021   - Karina de Paula
-- Redmine #74902/75152/75102
-- Liberado        - Release_2.9.6 e Patch_2.9.6.1
--
-- Em 11/01/2021   - Karina de Paula
-- Redmine #74870  - Ajuste na valida��o de SIGLA_IBGE_EMIT e DESCR_CIDADE_EMIT
-- Rotina Alterada - Ajuste na valida��o de SIGLA_IBGE_EMIT e DESCR_CIDADE_EMIT
-- Liberado        - Release_2.9.6
--
-- Em 18/12/2020   - Karina de Paula
-- Redmine #74308  - Teste de Integra��o CT-e
-- Rotina Alterada - pkb_ler_Conhec_Transp => Carregado os valores dt_sai_ent para o array pk_csf_api_ct.gt_row_conhec_transp
-- Liberado        - Release_2.9.6
--
-- Em 01/10/2020   - Armando/Luis Marques - 2.9.4-4 / 2.9.5-1 / 2.9.6
-- Redmine #71897  - Integra��o de CTe - Emiss�o Pr�pria - Documento Autorizado Adicionado por Gabriel 19 dias atr�s. 
--                   Atualizado aproximadamente 6 horas atr�s.
-- Rotina Alterada - pkb_ler_ct_int_ws - Incluida verifica��o para trazer apenas conhecimentos que n�o sejam legado (DM_LEGADO_0)
--
-- Em 20/09/2019   - Karina de Paula
-- Redmine #53132  - Atualizar Campos Chaves da View VW_CSF_CT_INF_OUTRO
-- Rotina Alterada - pkb_ler_r_outro_infunidtransp e pkb_ler_r_outro_infunidcarga => Incluido o campo NRO_DOCTO para ser usado como chave
--
-- Em: 19/09/2012 por Rog�rio Silva.
-- Foi adicionado o campo "NRO_CARREG" no processo de valida��o de conhecimento de transporte.
--
-- Em 24/07/2013 - Angela In�s.
-- Corre��es nas mensagens.
--
-- Em 12/09/2013
-- Atividade #600 -> Adicionado os procedimentos pkb_ler_conhec_transp_fat e pkb_ler_conhec_transp_dup e adicionado os campos DT_INI e DT_FIM na
-- valida��o do procedimento pkb_integr_conhec_transp_duto.
--
-- Em 05/01/2015 - Angela In�s.
-- Redmine #5616 - Adequa��o dos objetos que utilizam dos novos conceitos de Mult-Org.
--
-- Em 24/03/2015 - Leandro Savenhago.
-- Redmine #5372 - Adapta��es de processo de valida��o webservice.
--
-- Em 21/05/2015 - Rog�rio Silva.
-- Redmine #8054 - Implementar package pk_vld_amb_ws
--
-- Em 01/06/2015 - Rog�rio Silva
-- Redmine #8230 - Processo de Registro de Log em Packages - Conhecimento de Transporte
--
-- Em 30/09/2015 - Angela In�s.
-- Redmine #11914 - Acompanhar os processos que est�o sendo desenvolvidos.
-- Alterar a rotina pk_valida_ambiente_ct.pkb_integracao.pkb_ler_ct_integrados, considerar somente dm_ind_emit = 0-emiss�o pr�pria.
--
-- Em 05/02/2016 - Rog�rio Silva
-- Redmine #13079 - Registro do N�mero do Lote de Integra��o Web-Service nos logs de valida��o
--
-- Em 07/11/2017 - Leandro Savenhago
-- Redmine #33993 - Integra��o de CTe cuja emiss�o � propria legado atrav�s da Open Interface
-- Procedimento: pkb_ler_Conhec_Transp
--
-- Em 03/01/2018 - Marcelo Ono
-- Redmine #36866 - Atualiza��o no processo de valida��o de ambiente para o Conhecimento de Transporte para Emiss�o Pr�pria - CTe 3.0.
-- Rotinas: pkb_ler_Conhec_Transp, pkb_ler_Conhec_Transp_Compl, pkb_ler_Conhec_Transp_Imp, pkb_ler_ct_part_icms, pkb_ler_Conhec_Transp_Infcarga,
--          pkb_ler_Conhec_Transp_Subst, pkb_ler_ct_inf_vinc_mult, pkb_ler_conhec_transp_percurso, pkb_ler_ct_doc_ref_os, pkb_ler_ct_rodo_os,
--          pkb_ler_ct_aereo_peri, pkb_ler_ct_aquav_cont_nf, pkb_ler_ct_aquav_cont_nfe, pkb_ler_Conhec_Transp_Ferrov, pkb_ler_evento_cte_gtv,
--          pkb_ler_evento_cte_gtv_esp, pkb_ler_evento_cte_desac
--
-- Em 02/02/2018 - Angela In�s.
-- Redmine #39080 - Valida��o de Ambiente de Conhecimento de Transporte Emiss�o por Job Scheduller.
-- Rotinas: pkb_integracao, pkb_integracao_mo, pkb_ler_ct_integrados, pkb_ler_conhec_transp_canc e pkb_ler_evento_cte.
--
-- Em 17/04/2018 - Karina de Paula
-- Redmine #41660 - Altera��o processo de Integra��o de Conhecimento de Transporte, adicionando Integra��o de PIS e COFINS.
-- Rotina Criada: pkb_ler_conhec_transp_imp_out
-- Rotina Alterada: pkb_ler_Conhec_Transp - Inclu�da a chamada da pkb_ler_conhec_transp_imp_out
--
-- Em 20/04/2018 - Angela In�s.
-- Redmine #41822 - Reconsulta de CTe n�o executando na Amazon PRD pelo Job SCHEDULER (Tupperware)
-- Rotina: pkb_integracao_mo.
--
-- Em 20/09/2018 - Karina de Paula
-- Redmine #47066 - Integra��o de Conhecimento de Transporte
-- Rotina Alterada: pkb_ler_ct_integrados  / pkb_ler_Conhec_Transp_Canc e  pkb_ler_evento_cte(somente nvl sem inclus�o de LEGADO) /
--
-- Em 25/09/2018 - Karina de Paula
-- Redmine #47169 - Analisar o levantamento feito do CTE 3.0
-- Rotina Criada: pkb_ler_Conhec_Transp_email
-- Rotina Alterada: pkb_ler_Conhec_Transp => Incluida a chamada da pkb_ler_conhec_transp_email / pkb_ler_conhec_transp_tomador /
-- pkb_ler_conhec_transp_fat / pkb_ler_conhec_transp_dup
--
-- Em 27/11/2018 - Angela In�s.
-- Redmine #49137 - Altera��o na Integra��o e Valida��o de CTe.
-- Ao validar o conhecimento de transporte, via tela/portal, a rotina que est� sendo executada � pk_valida_ambiente_ct, por�m o processo que valida os valores
-- dos impostos, n�o est� considerando como "C�digo de Base de Cr�dito" o pr�prio valor do campo, e sim o "Valor da Base". Alterar para que seja enviado o
-- "C�digo de Base de Cr�dito", e esse seja validado.
-- Rotina: pkb_ler_conhec_transp_imp_out.
--
-- Em 25/09/2018 - Karina de Paula
-- Redmine #49178 - Package Validade Ambiente est� ficando em loop mais para CTe j� integrados dentro do Portal Compliance
-- Rotina Alterada: pkb_ler_ct_integrados => Retirado do cursor c_Conhec_Transp o select q trazia EMISS�O PR�PRIA - LEGADO
--
-------------------------------------------------------------------------------------------------------

--| Declara��o das vari�veis globais utilizadas no processo
   gn_multorg_id   mult_org.id%type;

-------------------------------------------------------------------------------------------------------
-- Procedimento faz a leitura das Informa��es dos registros de Conhecimento de Transporte

procedure pkb_ler_Conhec_Transp ( en_conhectransp_id in conhec_transp.id%type
                                , en_loteintws_id    in lote_int_ws.id%type default 0
                                );

-------------------------------------------------------------------------------------------------------

--| Procedimento que inicia a valida��o dos Conhecimentos de Transporte
procedure pkb_integracao;

-------------------------------------------------------------------------------------------------------

--| Procedimento que inicia a Valida��o de Conhecimento de Transporte Emiss�o atrav�s do Mult-Org.
--| Esse processo estar� sendo executado por JOB SCHEDULER, especif�camente para Ambiente Amazon.
--| A rotina dever� executar o mesmo procedimento da rotina pkb_integracao, por�m com a identifica��o da mult-org.
procedure pkb_integracao_mo ( en_multorg_id in mult_org.id%type );

-------------------------------------------------------------------------------------------------------

-- Procedimento de valida��o de dados de Conhecimento de Transporte Emiss�o Pr�pria, oriundos de Integra��o por Web-Service
procedure pkb_int_ws ( en_loteintws_id      in     lote_int_ws.id%type
                     , en_tipoobjintegr_id  in     tipo_obj_integr.id%type
                     , sn_erro              in out number
                     , sn_aguardar          out    number         -- 0-N�o; 1-Sim
                     );

-------------------------------------------------------------------------------------------------------

end pk_valida_ambiente_ct;
/
