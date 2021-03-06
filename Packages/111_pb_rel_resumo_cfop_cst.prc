create or replace procedure csf_own.pb_rel_resumo_cfop_cst(en_empresa_id  in empresa.id%type,
                                                           en_usuario_id  in neo_usuario.id%type,
                                                           en_tipoimp_id  in tipo_imposto.id%type,
                                                           en_codst_id    in cod_st.id%type, -- nulo quando n�o informado pela tela
                                                           en_cfop_id     in cfop.id%type, -- nulo quando n�o informado pela tela
                                                           ed_dt_ini      in date,
                                                           ed_dt_fin      in date,
                                                           en_consol_empr in number default 0) is
  /*
  Procedimento monta o relat�rio de resumo por CFOP e CST, considerando:
   Nota Fiscal (Emiss�o Pr�pria/Terceiros)
   Conhecimento de Transporte (Terceiros)
   Cupom Fiscal (Emiss�o Pr�pria)
   Notas Fiscais de Servi�os Cont�nuos (Terceiros)
  --
  Em 05/03/2021 - Luis Marques - 2.9.5-6 / 2.9.6-3 - 2.9.7
  Redmine #76565 - Verificar e caso n�o tenha colocar DT_COMPET nos resumos de CFOP (CST/ALIQ/UF)
  Incluido na dele��o de registros antigos o campo DT_COMPET e empresa_id.   
  --  
  Em 02/01/2019 - Renan Alves
  Redmine #62932 - Valor Base Outras - pb_rel_resumo_cfop_cst
  Foram inclu�das as colunas vl_bc_isenta_nt e vl_bc_outra na procedure pkb_seta_valores no momento em
  que a procedure alimenta o vetor pela primeira vez
  --
  Em 06/11/2019 - Allan Magrini
  Redmine #60888 - Valor Contabil SAT
  alterado no cursor c_icfe o campo ic.vl_prod para (nvl(ic.vl_item_liq,0) + nvl(ic.vl_rateio_descto,0)) vl_prod
  --
  Em 29/01/2019 - Marcos Ferreira
  Redmine #49524 - Funcionalidade - Base Isenta e Outros de Conhecimento de Transporte cuja emiss�o � pr�pria
  Solicita��o: Alterar a chamda da procedure pk_csf_api_d100.pkb_vlr_fiscal_ct_d100 para pk_csf_ct.pkb_vlr_fiscal_ct
  --
  Em 23/01/2019 - Angela In�s.
  Redmine #48915 - ICMS FCP e ICMS FCP ST.
  Atribuir os campos referente aos valores de FCP que s�o retornados na fun��o de valores do Item da Nota Fiscal (pkb_vlr_fiscal_item_nf).
  --
  Em 31/10/2017 - Angela In�s.
  Redmine #36123 - Melhoria t�cnica nos processos que geram relat�rios de impostos.
  Eliminar as fun��es que recuperam o c�digo do imposto (tipo_imposto.cd), atrav�s do par�metro de entrada, en_tipoimp_id, deixando a recupera��o uma
  �nica vez no in�cio do processo e utilizando uma vari�vel que armazena o c�digo (tipo_imposto.cd). Com isso, os testes que utilizavam a fun��o estar�o
  utilizando a vari�vel j� armazenada com o c�digo do tipo do imposto, evitando o select v�rias vezes.
  Fun��o: pk_csf.fkg_tipo_imposto_cd.
  --
  Em 04/11/2015 - Angela In�s.
  Redmine #12515 - Verificar/Alterar os relat�rios que ir�o atender o Cupom Fiscal Eletr�nico - CFe/SAT.
  --
  Em 23/07 e 11/08/2015 - Angela In�s.
  Redmine #10117 - Escritura��o de documentos fiscais - Processos.
  Inclus�o do novo conceito de recupera��o de data dos documentos fiscais para retorno dos registros.
  --
  Em 02/05/2014 - Angela In�s - Redmine #2763 - Corrigir o relat�rio de Resumo de Imposto de ICMS por CFOP e aliq e c�digo st.
  Com base na ficha #2381, � preciso corrigir tamb�m o relat�rio por CFOP e aliq e c�digo st.
  Print em anexo: "...n�o sair valores de ICMS em CFOP�s (1551, 1556, 3551 ...) que possuem valores mas n�o s�o recuperados na apura��o do ICMS."
  Al�m da solicita��o da atividade, foram feitas outras altera��es:
  1) Otimiza��o dos processos dos relat�rios de "Resumo por CFOP", "Resumo por CFOP e Al�quota", "Resumo por CFOP e C�digo de Situa��o Tribut�ria",
  "Resumo por CFOP e Estado", "Resumo por Al�quota de Imposto" e "Resumo por Estado".
  --
  Em 20/06/2013 - Angela In�s - Redmine Tarefa 78.
  O relat�rio de resumo de impostos de pis e cofins n�o estava considerando o layout de notas fiscais de servi�o (modelo 99).
  Lembrando que c�digo da situa��o 99 e 98, 70, 71, 72, 73, 74 e 75 n�o entram como base de cr�dito.
  --
  Em 11/06/2013 - Angela In�s.
  Excluir os dados da tabela rel_resumo_cfop_cst atrav�s do usu�rio (par�metro de entrada).
  --
  Em 28/06/2012 - Angela In�s - Ficha HD 60677.
  Incluir op��o de consolidado para empresas: en_consol_empr => 0-n�o, 1-sim.
  Consolidado = 0-n�o - ser� listado somente os dados da empresa conectada/logada.
  Consolidado = 1-sim - ser� listado os dados da empresa conectada/logada e suas filiais.
  --
  */
  --
  vn_fase number := 0;
  --
  vv_sigla_imp           tipo_imposto.sigla%type := null;
  vn_cd_imp              tipo_imposto.cd%type := null;
  vv_cod_st              cod_st.cod_st%type := null;
  vn_codst_id            cod_st.id%type := null;
  vn_codst_id_param      cod_st.id%type := null;
  vn_vl_base_calc        number := null;
  vn_vl_imp_trib         number := null;
  vn_vl_bc_imp_param     number := null;
  vn_vl_imp_imp_param    number := null;
  vn_vl_icms_st          number := null;
  vn_vl_icms             number := null;
  vn_vl_ii               number := null;
  vn_vl_ipi              number := null;
  vn_vl_red_base_calc    number(15, 2) := null;
  vn_dm_dt_escr_dfepoe   empresa.dm_dt_escr_dfepoe%type;
  --
  vn_vl_bc_outra         number := null;
  vn_vl_bc_outra_param   number := null;
  vn_vl_bc_isenta_param  number := null;
  vn_vl_bc_isenta        number := null;
  --
  -- Vari�veis para processos de recupera��es de valores de impostos ICMS e IPI das fun��es de valores (pk_csf):
  -- Utilizadas no processo:
  vn_cfop                number := null;
  vn_vl_operacao         number := null;
  vv_cod_st_icms         varchar2(3) := null;
  vn_vl_base_calc_icms   number := null;
  vn_vl_imp_trib_icms    number := null;
  vv_cod_st_ipi          varchar2(3) := null;
  vn_vl_base_calc_ipi    number := null;
  vn_vl_imp_trib_ipi     number := null;
  --
  -- Somente devido a fun��o
  vn_aliq_icms           number := null;
  vn_vl_bc_isenta_icms   number := null;
  vn_vl_bc_outra_icms    number := null;
  vn_vl_base_calc_icmsst number := null;
  vn_vl_imp_trib_icmsst  number := null;
  vn_aliq_ipi            number := null;
  vn_vl_bc_isenta_ipi    number := null;
  vn_vl_bc_outra_ipi     number := null;
  vn_ipi_nao_recup       number := null;
  vn_outro_ipi           number := null;
  vn_vl_imp_nao_dest_ipi number := null;
  vn_vl_fcp_icmsst       number;
  vn_aliq_fcp_icms       number;
  vn_vl_fcp_icms         number;
  --
  type t_tab_rel_resumo_cfop_cst is table of rel_resumo_cfop_cst%rowtype index by binary_integer;
  type t_bi_tab_rel_resumo_cfop_cst is table of t_tab_rel_resumo_cfop_cst index by binary_integer;
  vt_bi_tab_rel_resumo_cfop_cst t_bi_tab_rel_resumo_cfop_cst;
  --
  -- Query de Empresas devido a op��o de consolidado: 0-n�o, 1-sim
  cursor c_emp is
    select e2.id empresa_id,
           e2.dm_sm_icmsst_ipinrec_bs_outr
      from empresa e1, empresa e2
     where e1.id = en_empresa_id
       and ((en_consol_empr = 0 and e2.id = e1.id) -- 0-n�o, considerar a empresa conectada/logada
             or 
            (en_consol_empr = 1 and nvl(e2.ar_empresa_id, e2.id) = nvl(e1.ar_empresa_id, e1.id))) -- 1-sim, considerar empresa conectada/logada e suas filiais
     order by 1;
  --
  -- Query de Notas Fiscais
  cursor c_nf(en_empresa_id        in empresa.id%type,
              en_dm_dt_escr_dfepoe in empresa.dm_dt_escr_dfepoe%type) is
    select nf.id, 
           mf.cod_mod
      from nota_fiscal nf,  
           mod_fiscal mf
     where nf.empresa_id      = en_empresa_id
       and nf.dm_st_proc      = 4
       and nf.dm_arm_nfe_terc = 0
       and ((nf.dm_ind_emit = 1 and trunc(nvl(nf.dt_sai_ent, nf.dt_emiss)) between ed_dt_ini and ed_dt_fin) 
             or
            (nf.dm_ind_emit = 0 and nf.dm_ind_oper = 1 and trunc(nf.dt_emiss) between ed_dt_ini and ed_dt_fin) 
             or
            (nf.dm_ind_emit = 0 and nf.dm_ind_oper = 0 and en_dm_dt_escr_dfepoe = 0 and trunc(nf.dt_emiss) between ed_dt_ini and ed_dt_fin)
             or
            (nf.dm_ind_emit = 0 and nf.dm_ind_oper = 0 and en_dm_dt_escr_dfepoe = 1 and trunc(nvl(nf.dt_sai_ent, nf.dt_emiss)) between ed_dt_ini and ed_dt_fin))
       and mf.id = nf.modfiscal_id
       and mf.cod_mod in ('55', '65', '01', '04', '1B', '99', 'ND')
     order by 1;
  --
  -- Query de Itens das Notas
  cursor c_inf(en_notafiscal_id nota_fiscal.id%type) is
    select inf.id,
           inf.cfop,
           inf.vl_item_bruto,
           inf.vl_frete,
           inf.vl_seguro,
           inf.vl_outro,
           inf.vl_desc
      from item_nota_fiscal inf
     where inf.notafiscal_id = en_notafiscal_id
       and inf.cfop_id       = nvl(en_cfop_id, inf.cfop_id)
     order by inf.cfop;
  --
  -- Query conhecimento de transporte
  cursor c_ct(en_empresa_id        in empresa.id%type,
              en_dm_dt_escr_dfepoe in empresa.dm_dt_escr_dfepoe%type) is
    select ct.id
      from conhec_transp ct
     where ct.empresa_id      = en_empresa_id
       and ct.dm_st_proc      = 4
       and ct.dm_arm_cte_terc = 0
       and ((ct.dm_ind_emit = 1 and trunc(nvl(ct.dt_sai_ent, ct.dt_hr_emissao)) between ed_dt_ini and ed_dt_fin) 
             or
            (ct.dm_ind_emit = 0 and ct.dm_ind_oper = 1 and trunc(ct.dt_hr_emissao) between ed_dt_ini and ed_dt_fin) 
             or
            (ct.dm_ind_emit = 0 and ct.dm_ind_oper = 0 and en_dm_dt_escr_dfepoe = 0 and trunc(ct.dt_hr_emissao) between ed_dt_ini and ed_dt_fin) 
             or
            (ct.dm_ind_emit = 0 and ct.dm_ind_oper = 0 and en_dm_dt_escr_dfepoe = 1 and trunc(nvl(ct.dt_sai_ent, ct.dt_hr_emissao)) between ed_dt_ini and ed_dt_fin))
     order by 1;
  --
  -- Query de Registro Analitico de Conhecimento de Transporte
  cursor c_ct_anal(en_conhectransp_id in conhec_transp.id%type) is
    select r.id id,
           c.cd         cfop,
           r.codst_id   codst_id,
           r.vl_opr     vl_operacao,
           r.vl_bc_icms vl_bc_icms,
           r.vl_icms    vl_icms,
           r.vl_red_bc  vl_red_bc_icms
      from ct_reg_anal r, cfop c
     where r.conhectransp_id = en_conhectransp_id
       and r.cfop_id         = nvl(en_cfop_id, r.cfop_id)
       and r.codst_id        = nvl(en_codst_id, r.codst_id)
       and c.id              = r.cfop_id
     order by c.cd, 
              r.codst_id;
  --
  -- query de Registro PIS de Conhecimento de Transporte
  cursor c_ct_pis(en_conhectransp_id in conhec_transp.id%type) is
    select cc.codst_id, 
           cc.vl_item, 
           cc.vl_bc_pis, 
           cc.vl_pis
      from ct_comp_doc_pis cc
     where cc.conhectransp_id = en_conhectransp_id
       and cc.codst_id        = nvl(en_codst_id, cc.codst_id)
     order by 1;
  --
  -- Query de Registro COFINS de Conhecimento de Transporte
  cursor c_ct_cof(en_conhectransp_id in conhec_transp.id%type) is
    select cc.codst_id, 
           cc.vl_item, 
           cc.vl_bc_cofins, 
           cc.vl_cofins
      from ct_comp_doc_cofins cc
     where cc.conhectransp_id = en_conhectransp_id
       and cc.codst_id        = nvl(en_codst_id, cc.codst_id)
     order by 1;
  --
  -- Query cupom fiscal
  cursor c_cf(en_empresa_id in empresa.id%type) is
    select r.id reducaozecf_id
      from equip_ecf e, 
           reducao_z_ecf r
     where e.empresa_id  = en_empresa_id
       and r.equipecf_id = e.id
       and r.dm_st_proc  = 1 -- Validada
       and trunc(r.dt_doc) between trunc(ed_dt_ini) and trunc(ed_dt_fin)
     order by 1;
  --
  -- Query do Registro Analitico de ECF para ICMS
  cursor c_ecf_ra(en_reducaozecf_id in reducao_z_ecf.id%type) is
    select ra.id, 
           ra.codst_id
      from reg_anal_mov_dia_ecf ra
     where ra.reducaozecf_id = en_reducaozecf_id
       and ra.cfop_id        = nvl(en_cfop_id, ra.cfop_id)
       and ra.codst_id       = nvl(en_codst_id, ra.codst_id)
     order by 1;
  --
  -- Query de Registro PIS de Cupom Fiscal
  cursor c_cf_pis(en_reducaozecf_id in reducao_z_ecf.id%type) is
    select rd.codst_id,   
           rd.vl_item, 
           rd.vl_bc_pis, 
           rd.vl_pis
      from res_dia_doc_ecf_pis rd
     where rd.reducaozecf_id = en_reducaozecf_id
       and rd.codst_id       = nvl(en_codst_id, rd.codst_id)
     order by 1;
  --
  -- Query de Registro COFINS de Cupom Fiscal
  cursor c_cf_cof(en_reducaozecf_id in reducao_z_ecf.id%type) is
    select rd.codst_id, 
           rd.vl_item, 
           rd.vl_bc_cofins, 
           rd.vl_cofins
      from res_dia_doc_ecf_cofins rd
     where rd.reducaozecf_id = en_reducaozecf_id
       and rd.codst_id       = nvl(en_codst_id, rd.codst_id)
     order by 1;
  --
  -- query de servicos continuos
  cursor c_nfsc(en_empresa_id        in empresa.id%type,
                en_dm_dt_escr_dfepoe in empresa.dm_dt_escr_dfepoe%type) is
    select nf.id
      from nota_fiscal nf, mod_fiscal mf
     where nf.empresa_id      = en_empresa_id
       and nf.dm_st_proc      = 4
       and nf.dm_arm_nfe_terc = 0
       and ((nf.dm_ind_emit = 1 and trunc(nvl(nf.dt_sai_ent, nf.dt_emiss)) between ed_dt_ini and ed_dt_fin) 
             or
            (nf.dm_ind_emit = 0 and nf.dm_ind_oper = 1 and trunc(nf.dt_emiss) between ed_dt_ini and ed_dt_fin) 
             or
            (nf.dm_ind_emit = 0 and nf.dm_ind_oper = 0 and en_dm_dt_escr_dfepoe = 0 and trunc(nf.dt_emiss) between ed_dt_ini and ed_dt_fin) 
             or
            (nf.dm_ind_emit = 0 and nf.dm_ind_oper = 0 and en_dm_dt_escr_dfepoe = 1 and trunc(nvl(nf.dt_sai_ent, nf.dt_emiss)) between ed_dt_ini and ed_dt_fin))
       and mf.id = nf.modfiscal_id
       and mf.cod_mod in ('06', '29', '28', '21', '22')
     order by 1;
  --
  -- query de registro analit�co de NF de servi�o continuo
  cursor c_ranfsc(en_notafiscal_id nota_fiscal.id%type) is
    select c.cd cfop,
           r.codst_id,
           r.vl_operacao,
           r.vl_red_bc_icms,
           r.vl_ipi,
           r.id
      from nfregist_analit r, cfop c
     where r.notafiscal_id = en_notafiscal_id
       and r.cfop_id       = nvl(en_cfop_id, r.cfop_id)
       and r.codst_id      = nvl(en_codst_id, r.codst_id)
       and c.id = r.cfop_id
     order by 1, 2;
  --
  -- query de Registro PIS de NF de servi�o continuo
  cursor c_nfsc_pis(en_notafiscal_id nota_fiscal.id%type) is
    select nc.codst_id, 
           nc.vl_item, 
           nc.vl_bc_pis, 
           nc.vl_pis
      from nf_compl_oper_pis nc
     where nc.notafiscal_id = en_notafiscal_id
       and nc.codst_id      = nvl(en_codst_id, nc.codst_id)
     order by 1;
  --
  -- query de Registro COFINS de NF de servi�o continuo
  cursor c_nfsc_cof(en_notafiscal_id nota_fiscal.id%type) is
    select nc.codst_id, 
           nc.vl_item, 
           nc.vl_bc_cofins, 
           nc.vl_cofins
      from nf_compl_oper_cofins nc
     where nc.notafiscal_id = en_notafiscal_id
       and nc.codst_id      = nvl(en_codst_id, nc.codst_id)
     order by 1;
  --
  -- Query de Cupons Fiscais Eletr�nicos
  cursor c_cfe(en_empresa_id in empresa.id%type) is
    select cf.id, 
           mf.cod_mod
      from cupom_fiscal cf, 
           mod_fiscal mf
     where cf.empresa_id = en_empresa_id
       and cf.dm_st_proc = 4 -- autorizado
       and trunc(cf.dt_emissao) between ed_dt_ini and ed_dt_fin
       and mf.id         = cf.modfiscal_id
       and mf.cod_mod    = '59'
     order by 1;
  --
  -- Query de Itens dos Cupons Fiscais Eletr�nicos
  cursor c_icfe(en_cupomfiscal_id in cupom_fiscal.id%type) is
    select ic.id itemcf_id,
           cf.cd cd_cfop,
           (nvl(ic.vl_item_liq, 0) + nvl(ic.vl_rateio_descto, 0)) vl_prod,
           ic.vl_desc,
           ic.vl_outro,
           substr(cf.descr, 1, 255) descr_cfop
      from item_cupom_fiscal ic, 
           cfop cf
     where ic.cupomfiscal_id = en_cupomfiscal_id
       and ic.cfop_id        = nvl(en_cfop_id, ic.cfop_id)
       and cf.id             = ic.cfop_id
     order by cf.cd; -- cfop
  --
  procedure pkb_seta_valores(en_empresa_id       in empresa.id%type,
                             en_cfop             in cfop.cd%type,
                             en_codst_id         in cod_st.id%type,
                             en_vl_operacao      in rel_resumo_cfop_cst.vl_operacao%type,
                             en_vl_base_calc     in rel_resumo_cfop_cst.vl_base_calc%type,
                             en_vl_imp_trib      in rel_resumo_cfop_cst.vl_imp_trib%type,
                             en_vl_red_base_calc in rel_resumo_cfop_cst.vl_red_base_calc%type,
                             en_vl_bc_isenta_nt in rel_resumo_cfop_cst.vl_bc_isenta_nt%type,
                             en_vl_bc_outra     in rel_resumo_cfop_cst.vl_bc_outra%type) is
    --
    vb_achou boolean := false;
    --
  begin
    --
    begin
      --
      vb_achou := vt_bi_tab_rel_resumo_cfop_cst(en_cfop).exists(en_codst_id);
      --
    exception
      when others then
        vb_achou := false;
    end;
    --
    if not vb_achou then
      --
      begin
        --
        select relresumocfopcst_seq.nextval
          into vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).id
          from dual;
        --
      exception
        when others then
          vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).id := null;
      end;
      --
      if nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).id, 0) > 0 then
        --
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).empresa_id       := en_empresa_id;
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).usuario_id       := en_usuario_id;
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).sigla_imp        := vv_sigla_imp;
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).cfop             := en_cfop;
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).cod_st           := vv_cod_st;
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_operacao      := nvl(en_vl_operacao, 0);
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_base_calc     := nvl(en_vl_base_calc, 0);
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_imp_trib      := nvl(en_vl_imp_trib, 0);
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_red_base_calc := nvl(en_vl_red_base_calc, 0);
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_isenta_nt  := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_isenta_nt, 0) + nvl(en_vl_bc_isenta_nt, 0);
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_outra      := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_outra, 0) + nvl(en_vl_bc_outra, 0);
        vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).dt_compet        := ed_dt_ini;
        --
      end if;
      --
    else
      --
      vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_operacao      := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_operacao, 0) + nvl(en_vl_operacao, 0);
      vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_base_calc     := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_base_calc, 0) + nvl(en_vl_base_calc, 0);
      vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_imp_trib      := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_imp_trib, 0) + nvl(en_vl_imp_trib, 0);
      vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_red_base_calc := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_red_base_calc, 0) + nvl(en_vl_red_base_calc, 0);
      vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_isenta_nt  := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_isenta_nt, 0) + nvl(en_vl_bc_isenta_nt, 0);
      vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_outra      := nvl(vt_bi_tab_rel_resumo_cfop_cst(en_cfop)(en_codst_id).vl_bc_outra, 0) + nvl(en_vl_bc_outra, 0);
      --
    end if;
    --
  end pkb_seta_valores;
  --
  --| Procedimento Gravas os valores nas tabelas de banco
  procedure pkb_grava_rel_resumo_cfop is
    --
    pragma autonomous_transaction;
    vn_indice    number := 0;
    vn_indice_bi number := 0;
    --
  begin
    --
    vn_indice := nvl(vt_bi_tab_rel_resumo_cfop_cst.first, 0);
    --
    loop
      --
      if nvl(vn_indice, 0) = 0 then
        exit;
      end if;
      --
      vn_indice_bi := nvl(vt_bi_tab_rel_resumo_cfop_cst(vn_indice).first, 0);
      --
      loop
        --
        if nvl(vn_indice_bi, 0) = 0 then
          exit;
        end if;
        --
        insert into rel_resumo_cfop_cst
          (id,
           empresa_id,
           usuario_id,
           sigla_imp,
           cfop,
           cod_st,
           vl_operacao,
           vl_base_calc,
           vl_imp_trib,
           vl_red_base_calc,
           vl_bc_isenta_nt,
           vl_bc_outra,
           dt_compet)
        values
          (vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).id,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).empresa_id,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).usuario_id,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).sigla_imp,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).cfop,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).cod_st,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).vl_operacao,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).vl_base_calc,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).vl_imp_trib,
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).vl_red_base_calc,
           nvl(vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).vl_bc_isenta_nt, 0),
           nvl(vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).vl_bc_outra, 0),
           vt_bi_tab_rel_resumo_cfop_cst(vn_indice)(vn_indice_bi).dt_compet);
        --
        if vn_indice_bi = vt_bi_tab_rel_resumo_cfop_cst(vn_indice).last then
          exit;
        else
          vn_indice_bi := vt_bi_tab_rel_resumo_cfop_cst(vn_indice).next(vn_indice_bi);
        end if;
        --
      end loop;
      --
      if vn_indice = vt_bi_tab_rel_resumo_cfop_cst.last then
        exit;
      else
        vn_indice := vt_bi_tab_rel_resumo_cfop_cst.next(vn_indice);
      end if;
      --
    end loop;
    --
    commit;
    --
  end pkb_grava_rel_resumo_cfop;
  --
begin
  --
  vn_fase := 1;
  -- Remove os registros antigos conforme usu�rio
  begin
    delete 
      from rel_resumo_cfop_cst rr
     where rr.usuario_id = en_usuario_id
       and rr.empresa_id = en_empresa_id
       and rr.dt_compet  = ed_dt_ini;	 	 
  exception
    when others then
      raise_application_error(-20101, 'Problemas ao excluir dados gerados pelo usu�rio. Erro = ' || sqlerrm);
  end;
  --
  vn_fase := 2;
  --
  commit;
  --
  vn_fase := 3;
  --
  -- Sigla do imposto
  vv_sigla_imp := pk_csf.fkg_tipo_imp_sigla(en_id => en_tipoimp_id);
  vn_cd_imp    := pk_csf.fkg_Tipo_Imposto_cd(en_tipoimp_id => en_tipoimp_id);
  --
  vn_fase := 4;
  --
  -- Recupera as empresas
  for rec_emp in c_emp loop
    exit when c_emp%notfound or(c_emp%notfound) is null;
    --
    vn_fase := 5;
    --
    if nvl(rec_emp.empresa_id, 0) > 0 and nvl(en_usuario_id, 0) > 0 and nvl(en_tipoimp_id, 0) > 0 then
      --
      vn_fase := 6;
      --
      vt_bi_tab_rel_resumo_cfop_cst.delete;
      --
      vn_fase := 7;
      --
      vn_dm_dt_escr_dfepoe := pk_csf.fkg_dmdtescrdfepoe_empresa(en_empresa_id => en_empresa_id);
      --
      vn_fase := 7.1;
      --
      -- Separa as Nota Fiscais modelos: '55', '01', '04' e '1B'; e '99'
      for rec in c_nf(en_empresa_id        => rec_emp.empresa_id,
                      en_dm_dt_escr_dfepoe => vn_dm_dt_escr_dfepoe) loop
        exit when c_nf%notfound or(c_nf%notfound) is null;
        --
        vn_fase := 8;
        --
        if ((rec.cod_mod = '99' and upper(vv_sigla_imp) in ('PIS', 'COFINS')) or -- notas fiscais de servi�o para impostos pis e cofins
           (rec.cod_mod <> '99')) then -- os outros tipos de impostos e outros tipos de notas
          --
          vn_fase := 9;
          --
          for rec_inf in c_inf(en_notafiscal_id => rec.id) loop
            exit when c_inf%notfound or(c_inf%notfound) is null;
            --
            vn_fase := 10;
            --
            vn_vl_operacao        := null;
            vn_vl_base_calc       := null;
            vn_vl_imp_trib        := null;
            vn_codst_id           := null;
            vn_codst_id_param     := null;
            vn_vl_bc_imp_param    := null;
            vn_vl_imp_imp_param   := null;
            vn_vl_icms_st         := null;
            vn_vl_icms            := null;
            vn_vl_ii              := null;
            vn_vl_ipi             := null;
            vv_cod_st_icms        := null;
            vn_vl_base_calc_icms  := null;
            vn_vl_imp_trib_icms   := null;
            vv_cod_st_ipi         := null;
            vn_vl_base_calc_ipi   := null;
            vn_vl_imp_trib_ipi    := null;
            vn_vl_bc_isenta_param := null;
            vn_vl_bc_outra_param  := null;
            vn_vl_bc_outra_icms   := null;
            vn_vl_bc_isenta_ipi   := null;
            vn_vl_bc_outra_ipi    := null;
            --
            vn_fase := 11;
            --
            -- 1 - ICMS, 3 - IPI
            if nvl(vn_cd_imp, 0) not in (1, 3) then
              --
              vn_fase := 12;
              --
              -- Notas fiscais de servi�o
              if rec.cod_mod = '99' then
                --
                begin
                  select imp.codst_id,
                         nvl(sum(nvl(imp.vl_base_calc, 0)), 0),
                         nvl(sum(nvl(imp.vl_imp_trib, 0)), 0),
                         nvl(sum(nvl(imp.vl_base_isenta, 0)), 0),
                         nvl(sum(nvl(imp.vl_base_outro, 0)), 0)
                    into vn_codst_id_param,
                         vn_vl_bc_imp_param,
                         vn_vl_imp_imp_param,
                         vn_vl_bc_isenta_param,
                         vn_vl_bc_outra_param
                    from imp_itemnf imp, 
                         cod_st cs
                   where imp.itemnf_id  = rec_inf.id
                     and imp.tipoimp_id = en_tipoimp_id
                     and imp.codst_id   = nvl(en_codst_id, imp.codst_id)
                     and cs.id          = imp.codst_id
                     and cs.cod_st      not in ('70', '71', '72', '73', '74', '75', '99', '98')
                   group by imp.codst_id;
                exception
                  when others then
                    vn_codst_id_param     := null;
                    vn_vl_bc_imp_param    := null;
                    vn_vl_imp_imp_param   := null;
                    vn_vl_bc_isenta_param := null;
                    vn_vl_bc_outra_param  := null;
                    --
                end;
                --
              else
                --
                begin
                  select imp.codst_id,
                         nvl(sum(nvl(imp.vl_base_calc, 0)), 0),
                         nvl(sum(nvl(imp.vl_imp_trib, 0)), 0),
                         nvl(sum(nvl(imp.vl_base_isenta, 0)), 0),
                         nvl(sum(nvl(imp.vl_base_outro, 0)), 0)
                    into vn_codst_id_param,
                         vn_vl_bc_imp_param,
                         vn_vl_imp_imp_param,
                         vn_vl_bc_isenta_param,
                         vn_vl_bc_outra_param
                    from imp_itemnf imp
                   where imp.itemnf_id  = rec_inf.id
                     and imp.tipoimp_id = en_tipoimp_id
                     and imp.codst_id   = nvl(en_codst_id, imp.codst_id)
                   group by imp.codst_id;
                exception
                  when others then
                    vn_codst_id_param     := null;
                    vn_vl_bc_imp_param    := null;
                    vn_vl_imp_imp_param   := null;
                    vn_vl_bc_isenta_param := null;
                    vn_vl_bc_outra_param  := null;
                end;
                --
              end if;
              --
              vn_fase := 13;
              --
              -- Sempre zerara a base do CFOP 1604
              if rec_inf.cfop = 1604 then
                --
                vn_vl_bc_imp_param := 0;
                --
              end if;
              --
              vn_fase := 14;
              --
              -- Soma imposto de ICMS-ST
              begin
                select nvl(sum(nvl(imp.vl_imp_trib, 0)), 0)
                  into vn_vl_icms_st
                  from imp_itemnf imp, 
                       tipo_imposto ti
                 where imp.itemnf_id = rec_inf.id
                   and ti.id         = imp.tipoimp_id
                   and ti.cd         = 2;
              exception
                when others then
                  vn_vl_icms_st := null;
              end;
              --
              vn_fase := 15;
              --
              -- Soma imposto de IPI
              begin
                select nvl(sum(nvl(imp.vl_imp_trib, 0)), 0)
                  into vn_vl_ipi
                  from imp_itemnf imp, 
                       tipo_imposto ti
                 where imp.itemnf_id = rec_inf.id
                   and ti.id         = imp.tipoimp_id
                   and ti.cd         = 3;
              exception
                when others then
                  vn_vl_ipi := null;
              end;
              --
              vn_fase := 16;
              --
              -- Soma imposto de II
              begin
                select nvl(sum(nvl(imp.vl_imp_trib, 0)), 0)
                  into vn_vl_ii
                  from imp_itemnf imp, 
                       tipo_imposto ti
                 where imp.itemnf_id = rec_inf.id
                   and ti.id         = imp.tipoimp_id
                   and ti.cd         = 7;
              exception
                when others then
                  vn_vl_ii := null;
              end;
              --
              vn_fase := 17;
              --
              -- Soma imposto de ICMS
              begin
                select nvl(sum(nvl(imp.vl_imp_trib, 0)), 0)
                  into vn_vl_icms
                  from imp_itemnf imp, 
                       tipo_imposto ti
                 where imp.itemnf_id = rec_inf.id
                   and ti.id         = imp.tipoimp_id
                   and ti.cd         = 1;
              exception
                when others then
                  vn_vl_icms := null;
              end;
              --
              vn_fase := 18;
              --
              vn_vl_operacao := round((nvl(rec_inf.vl_item_bruto, 0) +
                                      nvl(rec_inf.vl_frete, 0) +
                                      nvl(rec_inf.vl_seguro, 0) +
                                      nvl(rec_inf.vl_outro, 0) +
                                      nvl(vn_vl_icms_st, 0) +
                                      nvl(vn_vl_ipi, 0) + nvl(vn_vl_ii, 0)) -
                                      nvl(rec_inf.vl_desc, 0),
                                      2);
              --
              vn_fase := 19;
              --
              if nvl(vn_vl_ii, 0) > 0 then
                --
                vn_fase := 20;
                --
                vn_vl_operacao := nvl(vn_vl_operacao, 0) + nvl(vn_vl_icms, 0);
                --
              end if;
              --
            end if;
            --
            vn_fase := 21;
            --
            -- 1 - ICMS, 3 - IPI
            if nvl(vn_cd_imp, 0) in (1, 3) then
              --
              vn_fase := 22;
              --
              -- Utilizada para recuperar os valores de base isenta e outras
              -- recupera os valores fiscais (ICMS/ICMS-ST/IPI) de um item de nota fiscal
              pk_csf_api.pkb_vlr_fiscal_item_nf(en_itemnf_id           => rec_inf.id,
                                                sn_cfop                => vn_cfop,
                                                sn_vl_operacao         => vn_vl_operacao,
                                                sv_cod_st_icms         => vv_cod_st_icms,
                                                sn_vl_base_calc_icms   => vn_vl_base_calc_icms,
                                                sn_aliq_icms           => vn_aliq_icms,
                                                sn_vl_imp_trib_icms    => vn_vl_imp_trib_icms,
                                                sn_vl_base_calc_icmsst => vn_vl_base_calc_icmsst,
                                                sn_vl_imp_trib_icmsst  => vn_vl_imp_trib_icmsst,
                                                sn_vl_bc_isenta_icms   => vn_vl_bc_isenta_icms,
                                                sn_vl_bc_outra_icms    => vn_vl_bc_outra_icms,
                                                sv_cod_st_ipi          => vv_cod_st_ipi,
                                                sn_vl_base_calc_ipi    => vn_vl_base_calc_ipi,
                                                sn_aliq_ipi            => vn_aliq_ipi,
                                                sn_vl_imp_trib_ipi     => vn_vl_imp_trib_ipi,
                                                sn_vl_bc_isenta_ipi    => vn_vl_bc_isenta_ipi,
                                                sn_vl_bc_outra_ipi     => vn_vl_bc_outra_ipi,
                                                sn_ipi_nao_recup       => vn_ipi_nao_recup,
                                                sn_outro_ipi           => vn_outro_ipi,
                                                sn_vl_imp_nao_dest_ipi => vn_vl_imp_nao_dest_ipi,
                                                sn_vl_fcp_icmsst       => vn_vl_fcp_icmsst,
                                                sn_aliq_fcp_icms       => vn_aliq_fcp_icms,
                                                sn_vl_fcp_icms         => vn_vl_fcp_icms);
              --
              vn_fase := 23;
              --
              -- 1 - ICMS
              if nvl(vn_cd_imp, 0) = 1 then
                --
                vn_fase := 24;
                --
                vn_codst_id         := pk_csf.fkg_cod_st_id(ev_cod_st     => vv_cod_st_icms,
                                                            en_tipoimp_id => en_tipoimp_id);
                vn_vl_base_calc     := nvl(vn_vl_base_calc_icms, 0);
                vn_vl_imp_trib      := nvl(vn_vl_imp_trib_icms, 0);
                vn_vl_bc_isenta     := nvl(vn_vl_bc_isenta_icms, 0);
                vn_vl_bc_outra_icms := nvl(vn_vl_bc_outra_icms, 0) +
                                       nvl(vn_vl_imp_trib_ipi, 0);
                --
                if nvl(rec_emp.dm_sm_icmsst_ipinrec_bs_outr, 0) = 1 then -- 1 - Sim
                  --
                  vn_vl_bc_outra := nvl(vn_vl_bc_outra_icms, 0) +
                                    nvl(vn_vl_imp_trib_icmsst, 0) +
                                    nvl(vn_ipi_nao_recup, 0) +
                                    nvl(vn_outro_ipi, 0);
                  --
                else
                  --
                  vn_vl_bc_outra := nvl(vn_vl_bc_outra_icms, 0);
                  --
                end if;
                --
              -- 3 - IPI
              elsif nvl(vn_cd_imp, 0) = 3 then
                --
                vn_fase := 25;
                --
                vn_codst_id     := pk_csf.fkg_cod_st_id(ev_cod_st     => vv_cod_st_ipi,
                                                        en_tipoimp_id => en_tipoimp_id);
                vn_vl_base_calc := nvl(vn_vl_base_calc_ipi, 0);
                vn_vl_imp_trib  := nvl(vn_vl_imp_trib_ipi, 0);
                vn_vl_bc_isenta := nvl(vn_vl_bc_isenta_ipi, 0);
                vn_vl_bc_outra  := nvl(vn_vl_bc_outra_ipi, 0);
                --
              end if;
              --
            -- Outros impostos - selecionados na tela  
            else
              --
              vn_fase         := 26;
              vn_codst_id     := vn_codst_id_param;
              vn_vl_base_calc := nvl(vn_vl_bc_imp_param, 0);
              vn_vl_imp_trib  := nvl(vn_vl_imp_imp_param, 0);
              vn_vl_bc_isenta := nvl(vn_vl_bc_isenta_param, 0);
              vn_vl_bc_outra  := nvl(vn_vl_bc_outra_param, 0);
              --
            end if;
            --
            vn_fase := 27;
            --
            vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => vn_codst_id);
            --
            vn_fase := 28;
            --
            if nvl(vn_codst_id, 0) = nvl(en_codst_id, nvl(vn_codst_id, 0)) then
              --
              vn_fase := 29;
              --
              pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                               en_cfop             => rec_inf.cfop,
                               en_codst_id         => nvl(vn_codst_id, 1), -- Passa "1" para n�o dar erro no �ndice do vetor
                               en_vl_operacao      => vn_vl_operacao,
                               en_vl_base_calc     => vn_vl_base_calc,
                               en_vl_imp_trib      => vn_vl_imp_trib,
                               en_vl_red_base_calc => 0,
                               en_vl_bc_isenta_nt => vn_vl_bc_isenta,
                               en_vl_bc_outra     => vn_vl_bc_outra);
              --
            end if;
            --
          end loop; -- c_inf
          --
        end if; -- modelos de notas e tipos de impostos
      --
      end loop; -- c_nf
      --
      vn_fase := 30;
      --
      -- Separa os Conhecimentos de Transportes
      for rec in c_ct(en_empresa_id        => rec_emp.empresa_id,
                      en_dm_dt_escr_dfepoe => vn_dm_dt_escr_dfepoe) loop
        --
        exit when c_ct%notfound or(c_ct%notfound) is null;
        --
        vn_fase := 31;
        --
        for rec_ct_anal in c_ct_anal(en_conhectransp_id => rec.id) loop
          exit when c_ct_anal%notfound or(c_ct_anal%notfound) is null;
          --
          vn_fase              := 31.1;
          vn_vl_bc_isenta_icms := null;
          vn_vl_bc_outra_icms  := null;
          --
          vn_fase := 32;
          -- 
          -- 1 - ICMS
          if nvl(vn_cd_imp, 0) = 1 then
            --
            vn_fase := 33;
            --
            vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_ct_anal.codst_id);
            --
            vn_fase := 32;
            --
            -- Recupera os valores de impostos - ICMS
            pk_csf_ct.pkb_vlr_fiscal_ct(en_ctreganal_id      => rec_ct_anal.id,
                                        sv_cod_st_icms       => vv_cod_st_icms,
                                        sn_cfop              => vn_cfop,
                                        sn_aliq_icms         => vn_aliq_icms,
                                        sn_vl_opr            => vn_vl_operacao,
                                        sn_vl_bc_icms        => vn_vl_base_calc_icms,
                                        sn_vl_icms           => vn_vl_imp_trib_icms,
                                        sn_vl_bc_isenta_icms => vn_vl_bc_isenta_icms,
                                        sn_vl_bc_outra_icms  => vn_vl_bc_outra_icms);
            --
            vn_fase := 34;
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => rec_ct_anal.cfop,
                             en_codst_id         => nvl(rec_ct_anal.codst_id, 1),
                             en_vl_operacao      => rec_ct_anal.vl_operacao,
                             en_vl_base_calc     => rec_ct_anal.vl_bc_icms,
                             en_vl_imp_trib      => rec_ct_anal.vl_icms,
                             en_vl_red_base_calc => rec_ct_anal.vl_red_bc_icms,
                             en_vl_bc_isenta_nt  => vn_vl_bc_isenta_icms,
                             en_vl_bc_outra      => vn_vl_bc_outra_icms);
            --
          end if;
          --
          vn_fase := 35;
          -- 
          -- 3 - IPI
          if nvl(vn_cd_imp, 0) = 3 then
            --
            vn_fase := 36;
            --
            vv_cod_st := 1;
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => rec_ct_anal.cfop,
                             en_codst_id         => 1,
                             en_vl_operacao      => rec_ct_anal.vl_operacao,
                             en_vl_base_calc     => null,
                             en_vl_imp_trib      => null,
                             en_vl_red_base_calc => null,
                             en_vl_bc_isenta_nt  => null,
                             en_vl_bc_outra      => null);
            --
          end if;
          --
          vn_fase := 37;
          -- 
          -- 4 - PIS
          if nvl(vn_cd_imp, 0) = 4 then
            --
            vn_fase := 38;
            --
            for rec_ct_pis in c_ct_pis(en_conhectransp_id => rec.id) loop
              exit when c_ct_pis%notfound or(c_ct_pis%notfound) is null;
              --
              vn_fase := 39;
              --
              vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_ct_pis.codst_id);
              --
              pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                               en_cfop             => rec_ct_anal.cfop,
                               en_codst_id         => nvl(rec_ct_pis.codst_id, 1),
                               en_vl_operacao      => rec_ct_pis.vl_item,
                               en_vl_base_calc     => rec_ct_pis.vl_bc_pis,
                               en_vl_imp_trib      => rec_ct_pis.vl_pis,
                               en_vl_red_base_calc => (nvl(rec_ct_pis.vl_item, 0) - nvl(rec_ct_pis.vl_bc_pis, 0)),
                               en_vl_bc_isenta_nt  => null,
                               en_vl_bc_outra      => null);
              --
            end loop; -- c_ct_pis
            --
          end if;
          --
          vn_fase := 40;
          -- 
          -- 5 - COFINS
          if nvl(vn_cd_imp, 0) = 5 then
            --
            vn_fase := 41;
            --
            for rec_ct_cof in c_ct_cof(en_conhectransp_id => rec.id) loop
              exit when c_ct_cof%notfound or(c_ct_cof%notfound) is null;
              --
              vn_fase := 42;
              --
              vv_cod_st := pk_csf.fkg_Cod_ST_cod(en_id_st => rec_ct_cof.codst_id);
              --
              pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                               en_cfop             => rec_ct_anal.cfop,
                               en_codst_id         => nvl(rec_ct_cof.codst_id, 1),
                               en_vl_operacao      => rec_ct_cof.vl_item,
                               en_vl_base_calc     => rec_ct_cof.vl_bc_cofins,
                               en_vl_imp_trib      => rec_ct_cof.vl_cofins,
                               en_vl_red_base_calc => (nvl(rec_ct_cof.vl_item, 0) - nvl(rec_ct_cof.vl_bc_cofins, 0)),
                               en_vl_bc_isenta_nt => null,
                               en_vl_bc_outra     => null);
              --
            end loop; -- c_ct_cof
            --
          end if;
          --
        end loop; -- c_ct_anal
        --
      end loop; -- c_ct
      --
      vn_fase := 43;
      --
      -- Separa os Cupons Fiscais
      for rec in c_cf(en_empresa_id => rec_emp.empresa_id) loop
        --
        exit when c_cf%notfound or(c_cf%notfound) is null;
        --
        vn_fase := 44;
        -- 
        -- 1 - ICMS
        if nvl(vn_cd_imp, 0) = 1 then
          --
          vn_fase := 45;
          --
          for rec_ecf_ra in c_ecf_ra(en_reducaozecf_id => rec.reducaozecf_id) loop
            --
            exit when c_ecf_ra%notfound or(c_ecf_ra%notfound) is null;
            --
            vn_fase := 46;
            --
            vn_cfop              := null;
            vv_cod_st_icms       := null;
            vn_vl_operacao       := 0;
            vn_vl_base_calc_icms := 0;
            vn_vl_imp_trib_icms  := 0;
            --
            vn_vl_bc_isenta_icms := 0;
            vn_vl_bc_outra_icms  := 0;
            --
            vn_fase := 47;
            --
            pk_csf_api_ecf.pkb_vlr_fiscal_ecf(en_reganalmovdiaecf_id => rec_ecf_ra.id,
                                              sv_cod_st_icms         => vv_cod_st_icms,
                                              sn_cfop                => vn_cfop,
                                              sn_aliq_icms           => vn_aliq_icms,
                                              sn_vl_opr              => vn_vl_operacao,
                                              sn_vl_bc_icms          => vn_vl_base_calc_icms,
                                              sn_vl_icms             => vn_vl_imp_trib_icms,
                                              sn_vl_bc_isenta_icms   => vn_vl_bc_isenta_icms,
                                              sn_vl_bc_outra_icms    => vn_vl_bc_outra_icms);
            --
            vn_fase := 48;
            --
            if vn_cfop in (5929, 6929, 5602, 6602) then
              --
              vn_vl_operacao       := 0;
              vn_vl_base_calc_icms := 0;
              vn_vl_imp_trib_icms  := 0;
              --
              vn_vl_bc_isenta_icms := 0;
              vn_vl_bc_outra_icms  := 0;
              --
            elsif vn_cfop in (1551, 1556, 3551, 3949, 3556) then
              --
              vn_vl_bc_isenta_icms := nvl(vn_vl_base_calc_icms, 0);
              vn_vl_bc_outra_icms  := nvl(vn_vl_imp_trib_icms, 0);
              --
              vn_vl_base_calc_icms := 0;
              vn_vl_imp_trib_icms  := 0;
              --
            end if;
            --
            vn_fase := 49;
            --
            vv_cod_st := vv_cod_st_icms;
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => vn_cfop,
                             en_codst_id         => rec_ecf_ra.codst_id,
                             en_vl_operacao      => vn_vl_operacao,
                             en_vl_base_calc     => vn_vl_base_calc_icms,
                             en_vl_imp_trib      => vn_vl_imp_trib_icms,
                             en_vl_red_base_calc => 0,
                             en_vl_bc_isenta_nt => vn_vl_bc_isenta_icms,
                             en_vl_bc_outra     => vn_vl_bc_outra_icms);
            --
          end loop;
          --
        end if;
        --
        vn_fase := 50;
        -- 
        -- 4 - PIS
        if nvl(vn_cd_imp, 0) = 4 then
          --
          vn_fase := 51;
          --
          for rec_cf_pis in c_cf_pis(en_reducaozecf_id => rec.reducaozecf_id) loop
            exit when c_cf_pis%notfound or(c_cf_pis%notfound) is null;
            --
            vn_fase := 52;
            --
            vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_cf_pis.codst_id);
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => 1,
                             en_codst_id         => nvl(rec_cf_pis.codst_id, 1),
                             en_vl_operacao      => rec_cf_pis.vl_item,
                             en_vl_base_calc     => rec_cf_pis.vl_bc_pis,
                             en_vl_imp_trib      => rec_cf_pis.vl_pis,
                             en_vl_red_base_calc => (nvl(rec_cf_pis.vl_item, 0) - nvl(rec_cf_pis.vl_bc_pis, 0)),
                             en_vl_bc_isenta_nt => null,
                             en_vl_bc_outra     => null);
            --
          end loop; -- c_cf_pis
          --
        end if;
        --
        vn_fase := 53;
        -- 
        -- 5 - COFINS
        if nvl(vn_cd_imp, 0) = 5 then
          --
          vn_fase := 54;
          --
          for rec_cf_cof in c_cf_cof(en_reducaozecf_id => rec.reducaozecf_id) loop
            exit when c_cf_cof%notfound or(c_cf_cof%notfound) is null;
            --
            vn_fase := 55;
            --
            vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_cf_cof.codst_id);
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => 1,
                             en_codst_id         => nvl(rec_cf_cof.codst_id, 1),
                             en_vl_operacao      => rec_cf_cof.vl_item,
                             en_vl_base_calc     => rec_cf_cof.vl_bc_cofins,
                             en_vl_imp_trib      => rec_cf_cof.vl_cofins,
                             en_vl_red_base_calc => (nvl(rec_cf_cof.vl_item, 0) - nvl(rec_cf_cof.vl_bc_cofins, 0)),
                             en_vl_bc_isenta_nt  => null,
                             en_vl_bc_outra      => null);
            --
          end loop; -- c_cf_cof
          --
        end if;
        --
      end loop; -- c_cf
      --
      vn_fase := 56;
      --
      -- Separa as Notas Fiscais de Servi�os COnt�nuos. Modelos: '06', '29', '28', '21' e '22'
      for rec in c_nfsc(en_empresa_id        => rec_emp.empresa_id,
                        en_dm_dt_escr_dfepoe => vn_dm_dt_escr_dfepoe) loop
        --
        exit when c_nfsc%notfound or(c_nfsc%notfound) is null;
        --
        vn_fase := 57;
        --
        for rec_ranfsc in c_ranfsc(en_notafiscal_id => rec.id) loop
          --
          exit when c_ranfsc%notfound or(c_ranfsc%notfound) is null;
          --
          vn_fase := 58;
          -- 
          -- 1 - ICMS
          if nvl(vn_cd_imp, 0) = 1 then
            --
            vn_fase := 59;
            --
            vn_vl_operacao       := null;
            vn_vl_base_calc_icms := null;
            vn_vl_imp_trib_icms  := null;
            vn_vl_red_base_calc  := rec_ranfsc.vl_red_bc_icms;
            vn_vl_bc_isenta_icms := null;
            vn_vl_bc_outra_icms  := null;
            --
            vn_fase := 60;
            --
            -- Recupera valores fiscais (ICMS/ICMS-ST/IPI) de uma nota fiscal de servi�o continuo
            pk_csf_api.pkb_vlr_fiscal_nfsc(en_nfregistanalit_id => rec_ranfsc.id,
                                           sv_cod_st_icms       => vv_cod_st_icms,
                                           sn_cfop              => vn_cfop,
                                           sn_aliq_icms         => vn_aliq_icms,
                                           sn_vl_operacao       => vn_vl_operacao,
                                           sn_vl_bc_icms        => vn_vl_base_calc_icms,
                                           sn_vl_icms           => vn_vl_imp_trib_icms,
                                           sn_vl_bc_icmsst      => vn_vl_base_calc_icmsst,
                                           sn_vl_icms_st        => vn_vl_imp_trib_icmsst,
                                           sn_vl_ipi            => vn_vl_imp_trib_ipi,
                                           sn_vl_bc_isenta_icms => vn_vl_bc_isenta_icms,
                                           sn_vl_bc_outra_icms  => vn_vl_bc_outra_icms);
            --
            vn_fase := 61;
            --
            if rec_ranfsc.cfop in
               (5929, 6929, 3551, 3949, 5602, 6602, 3556) then
              --
              if rec_ranfsc.cfop in (5929, 6929, 5602, 6602) then
                --
                vn_vl_operacao := 0;
                --
              end if;
              --
              vn_vl_base_calc_icms := 0;
              vn_vl_imp_trib_icms  := 0;
              vn_vl_red_base_calc  := 0;
              vn_vl_bc_isenta_icms := 0;
              vn_vl_bc_outra_icms  := 0;
              --
            end if;
            --
            vn_fase := 62;
            --
            vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_ranfsc.codst_id);
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => rec_ranfsc.cfop,
                             en_codst_id         => rec_ranfsc.codst_id,
                             en_vl_operacao      => nvl(vn_vl_operacao, 0),
                             en_vl_base_calc     => nvl(vn_vl_base_calc_icms, 0),
                             en_vl_imp_trib      => nvl(vn_vl_imp_trib_icms, 0),
                             en_vl_red_base_calc => nvl(vn_vl_red_base_calc, 0),
                             en_vl_bc_isenta_nt  => vn_vl_bc_isenta_icms,
                             en_vl_bc_outra      => vn_vl_bc_outra_icms);
            --
          end if;
          --
          vn_fase := 63;
          -- 
          -- 3 - IPI
          if nvl(vn_cd_imp, 0) = 3 then
            --
            vn_fase := 64;
            --
            vv_cod_st := 1;
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => rec_ranfsc.cfop,
                             en_codst_id         => 1,
                             en_vl_operacao      => rec_ranfsc.vl_operacao,
                             en_vl_base_calc     => null,
                             en_vl_imp_trib      => rec_ranfsc.vl_ipi,
                             en_vl_red_base_calc => null,
                             en_vl_bc_isenta_nt  => null,
                             en_vl_bc_outra      => null);
            --
          end if;
          --
          vn_fase := 65;
          -- 
          -- 4 - PIS
          if nvl(vn_cd_imp, 0) = 4 then
            --
            vn_fase := 66;
            --
            for rec_nfsc_pis in c_nfsc_pis(en_notafiscal_id => rec.id) loop
              --
              exit when c_nfsc_pis%notfound or(c_nfsc_pis%notfound) is null;
              --
              vn_fase := 67;
              --
              vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_nfsc_pis.codst_id);
              --
              pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                               en_cfop             => rec_ranfsc.cfop,
                               en_codst_id         => nvl(rec_nfsc_pis.codst_id, 1),
                               en_vl_operacao      => rec_nfsc_pis.vl_item,
                               en_vl_base_calc     => rec_nfsc_pis.vl_bc_pis,
                               en_vl_imp_trib      => rec_nfsc_pis.vl_pis,
                               en_vl_red_base_calc => (nvl(rec_nfsc_pis.vl_item, 0) - nvl(rec_nfsc_pis.vl_bc_pis, 0)),
                               en_vl_bc_isenta_nt  => null,
                               en_vl_bc_outra      => null);
              --
            end loop;
            --
          end if;
          --
          vn_fase := 68;
          -- 
          -- 5 - COFINS
          if nvl(vn_cd_imp, 0) = 5 then
            --
            vn_fase := 69;
            --
            for rec_nfsc_cof in c_nfsc_cof(en_notafiscal_id => rec.id) loop
              --
              exit when c_nfsc_cof%notfound or(c_nfsc_cof%notfound) is null;
              --
              vn_fase := 70;
              --
              vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => rec_nfsc_cof.codst_id);
              --
              pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                               en_cfop             => rec_ranfsc.cfop,
                               en_codst_id         => nvl(rec_nfsc_cof.codst_id, 1),
                               en_vl_operacao      => rec_nfsc_cof.vl_item,
                               en_vl_base_calc     => rec_nfsc_cof.vl_bc_cofins,
                               en_vl_imp_trib      => rec_nfsc_cof.vl_cofins,
                               en_vl_red_base_calc => (nvl(rec_nfsc_cof.vl_item, 0) - nvl(rec_nfsc_cof.vl_bc_cofins, 0)),
                               en_vl_bc_isenta_nt  => null,
                               en_vl_bc_outra      => null);
              --
            end loop;
            --
          end if;
          --
        end loop;
        --
      end loop; -- c_nfsc
      --
      vn_fase := 71;
      --
      -- Separa os Cupons Fiscais modelo: '59'
      for rec in c_cfe(en_empresa_id => rec_emp.empresa_id) loop
        --
        exit when c_cfe%notfound or(c_cfe%notfound) is null;
        --
        vn_fase := 72;
        --
        for rec_icfe in c_icfe(en_cupomfiscal_id => rec.id) loop
          --
          exit when c_icfe%notfound or(c_icfe%notfound) is null;
          --
          vn_fase := 73;
          --
          vn_vl_operacao       := null;
          vn_vl_base_calc      := null;
          vn_vl_imp_trib       := null;
          vn_codst_id          := null;
          vn_codst_id_param    := null;
          vn_vl_bc_imp_param   := null;
          vn_vl_imp_imp_param  := null;
          vn_vl_icms_st        := null;
          vn_vl_icms           := null;
          vn_vl_ii             := null;
          vn_vl_ipi            := null;
          vv_cod_st_icms       := null;
          vn_vl_base_calc_icms := null;
          vn_vl_imp_trib_icms  := null;
          vv_cod_st_ipi        := null;
          vn_vl_base_calc_ipi  := null;
          vn_vl_imp_trib_ipi   := null;
          --
          vn_vl_bc_isenta_icms := null;
          vn_vl_bc_outra_icms  := null;
          vn_vl_bc_isenta_ipi  := null;
          vn_vl_bc_outra_ipi   := null;
          vn_vl_bc_isenta      := null;
          vn_vl_bc_outra       := null;
          --
          vn_fase := 74;
          --
          -- 1-ICMS, 3-IPI
          if nvl(vn_cd_imp, 0) not in (1, 3) then
            --
            vn_fase := 75;
            --
            begin
              select ii.codst_id,
                     nvl(sum(nvl(ii.vl_base_calc, 0)), 0),
                     nvl(sum(nvl(ii.vl_imp_trib, 0)), 0)
                into vn_codst_id_param,
                     vn_vl_bc_imp_param,
                     vn_vl_imp_imp_param
                from imp_itemcf ii
               where ii.itemcupomfiscal_id = rec_icfe.itemcf_id
                 and ii.tipoimp_id         = en_tipoimp_id
                 and ii.codst_id           = nvl(en_codst_id, ii.codst_id)
               group by ii.codst_id;
            exception
              when others then
                vn_codst_id_param   := null;
                vn_vl_bc_imp_param  := null;
                vn_vl_imp_imp_param := null;
            end;
            --
            vn_fase := 76;
            --
            -- Sempre zerara a base do CFOP 1604
            if rec_icfe.cd_cfop = 1604 then
              --
              vn_vl_bc_imp_param := 0;
              --
            end if;
            --
            vn_fase := 77;
            --
            -- Soma imposto de ICMS-ST
            begin
              select nvl(sum(nvl(ii.vl_imp_trib, 0)), 0)
                into vn_vl_icms_st
                from imp_itemcf ii, tipo_imposto ti
               where ii.itemcupomfiscal_id = rec_icfe.itemcf_id
                 and ti.id                 = ii.tipoimp_id
                 and ti.cd                 = 2;
            exception
              when others then
                vn_vl_icms_st := null;
            end;
            --
            vn_fase := 78;
            --
            -- Soma imposto de IPI
            begin
              select nvl(sum(nvl(ii.vl_imp_trib, 0)), 0)
                into vn_vl_ipi
                from imp_itemcf ii,
                     tipo_imposto ti
               where ii.itemcupomfiscal_id = rec_icfe.itemcf_id
                 and ti.id                 = ii.tipoimp_id
                 and ti.cd                 = 3;
            exception
              when others then
                vn_vl_ipi := null;
            end;
            --
            vn_fase := 79;
            --
            -- Soma imposto de II
            begin
              select nvl(sum(nvl(ii.vl_imp_trib, 0)), 0)
                into vn_vl_ii
                from imp_itemcf ii, 
                     tipo_imposto ti
               where ii.itemcupomfiscal_id = rec_icfe.itemcf_id
                 and ti.id                 = ii.tipoimp_id
                 and ti.cd                 = 7;
            exception
              when others then
                vn_vl_ii := null;
            end;
            --
            vn_fase := 80;
            --
            -- Soma imposto de ICMS
            begin
              select nvl(sum(nvl(ii.vl_imp_trib, 0)), 0)
                into vn_vl_icms
                from imp_itemcf ii, 
                     tipo_imposto ti
               where ii.itemcupomfiscal_id = rec_icfe.itemcf_id
                 and ti.id                 = ii.tipoimp_id
                 and ti.cd                 = 1;
            exception
              when others then
                vn_vl_icms := null;
            end;
            --
            vn_fase := 81;
            --
            vn_vl_operacao := round((nvl(rec_icfe.vl_prod, 0) +
                                     nvl(rec_icfe.vl_outro, 0) +
                                     nvl(vn_vl_icms_st, 0) +
                                     nvl(vn_vl_ipi, 0) + nvl(vn_vl_ii, 0)) -
                                     nvl(rec_icfe.vl_desc, 0),
                                     2);
            --
            vn_fase := 82;
            --
            if nvl(vn_vl_ii, 0) > 0 then
              --
              vn_fase := 83;
              --
              vn_vl_operacao := nvl(vn_vl_operacao, 0) + nvl(vn_vl_icms, 0);
              --
            end if;
            --
          end if;
          --
          vn_fase := 84;
          --
          -- 1-ICMS, 3-IPI
          if nvl(vn_cd_imp, 0) in (1, 3) then
            --
            vn_fase := 85;
            --
            -- Recupera os valores fiscais (ICMS/ICMS-ST/IPI) de um item do cupom fiscal
            pk_csf_api.pkb_vlr_fiscal_item_cfe(en_itemcupomfiscal_id  => rec_icfe.itemcf_id,
                                               sn_cfop                => vn_cfop,
                                               sn_vl_operacao         => vn_vl_operacao,
                                               sv_cod_st_icms         => vv_cod_st_icms,
                                               sn_vl_base_calc_icms   => vn_vl_base_calc_icms,
                                               sn_aliq_icms           => vn_aliq_icms,
                                               sn_vl_imp_trib_icms    => vn_vl_imp_trib_icms,
                                               sn_vl_base_calc_icmsst => vn_vl_base_calc_icmsst,
                                               sn_vl_imp_trib_icmsst  => vn_vl_imp_trib_icmsst,
                                               sn_vl_bc_isenta_icms   => vn_vl_bc_isenta_icms,
                                               sn_vl_bc_outra_icms    => vn_vl_bc_outra_icms,
                                               sv_cod_st_ipi          => vv_cod_st_ipi,
                                               sn_vl_base_calc_ipi    => vn_vl_base_calc_ipi,
                                               sn_aliq_ipi            => vn_aliq_ipi,
                                               sn_vl_imp_trib_ipi     => vn_vl_imp_trib_ipi,
                                               sn_vl_bc_isenta_ipi    => vn_vl_bc_isenta_ipi,
                                               sn_vl_bc_outra_ipi     => vn_vl_bc_outra_ipi,
                                               sn_ipi_nao_recup       => vn_ipi_nao_recup,
                                               sn_outro_ipi           => vn_outro_ipi);
            --
            vn_fase := 86;
            --
            -- 1 - ICMS
            if nvl(vn_cd_imp, 0) = 1 then 
              --
              vn_fase         := 87;
              --
              vn_codst_id     := pk_csf.fkg_cod_st_id(ev_cod_st     => vv_cod_st_icms,
                                                      en_tipoimp_id => en_tipoimp_id);
              vn_vl_base_calc := nvl(vn_vl_base_calc_icms, 0);
              vn_vl_imp_trib  := nvl(vn_vl_imp_trib_icms, 0);
              vn_vl_bc_isenta := nvl(vn_vl_bc_isenta_icms, 0);
              --
              if nvl(rec_emp.dm_sm_icmsst_ipinrec_bs_outr, 0) = 1 then -- 1 - sim
                --
                vn_vl_bc_outra := nvl(vn_vl_bc_outra_icms, 0) +
                                  nvl(vn_vl_imp_trib_icmsst, 0) +
                                  nvl(vn_ipi_nao_recup, 0) +
                                  nvl(vn_outro_ipi, 0);
              else
                --
                vn_vl_bc_outra := nvl(vn_vl_bc_outra_icms, 0);
                --
              end if;
              --
            elsif nvl(vn_cd_imp, 0) = 3 then
              -- 3-IPI
              --
              vn_fase         := 88;
              vn_codst_id     := pk_csf.fkg_cod_st_id(ev_cod_st     => vv_cod_st_ipi,
                                                      en_tipoimp_id => en_tipoimp_id);
              vn_vl_base_calc := nvl(vn_vl_base_calc_ipi, 0);
              vn_vl_imp_trib  := nvl(vn_vl_imp_trib_ipi, 0);
              --
              vn_vl_bc_isenta := nvl(vn_vl_bc_isenta_ipi, 0);
              vn_vl_bc_outra  := nvl(vn_vl_bc_outra_ipi, 0);
              --
            end if;
            --
          -- Outros impostos - selecionados na tela  
          else
            --
            vn_fase         := 89;
            --
            vn_codst_id     := vn_codst_id_param;
            vn_vl_base_calc := nvl(vn_vl_bc_imp_param, 0);
            vn_vl_imp_trib  := nvl(vn_vl_imp_imp_param, 0);
            --
            vn_vl_bc_isenta := nvl(vn_vl_bc_isenta_param, 0);
            vn_vl_bc_outra  := nvl(vn_vl_bc_outra_param, 0);
            --
          end if;
          --
          vn_fase := 90;
          --
          vv_cod_st := pk_csf.fkg_cod_st_cod(en_id_st => vn_codst_id);
          --
          vn_fase := 91;
          --
          if nvl(vn_codst_id, 0) = nvl(en_codst_id, nvl(vn_codst_id, 0)) then
            --
            vn_fase := 92;
            --
            pkb_seta_valores(en_empresa_id       => rec_emp.empresa_id,
                             en_cfop             => rec_icfe.cd_cfop,
                             en_codst_id         => nvl(vn_codst_id, 1), -- Passa "1" para n�o dar erro no �ndice do vetor
                             en_vl_operacao      => vn_vl_operacao,
                             en_vl_base_calc     => vn_vl_base_calc,
                             en_vl_imp_trib      => vn_vl_imp_trib,
                             en_vl_red_base_calc => 0,
                             en_vl_bc_isenta_nt  => vn_vl_bc_isenta,
                             en_vl_bc_outra      => vn_vl_bc_outra);
            --
          end if;
          --
        end loop; -- c_icfe
      --
      end loop; -- c_cfe
      --
      vn_fase := 93;
      --
      -- Salva os registros
      pkb_grava_rel_resumo_cfop;
      --
    end if; -- final do teste: rec_emp.empresa_id > 0 e en_usuario_id > 0 e en_tipoimp_id > 0
  --
  end loop; -- c_emp
  --
exception
  when others then
    raise_application_error(-20101, 'Erro na pb_rel_resumo_cfop_cst fase(' || vn_fase || '): ' || sqlerrm);
end pb_rel_resumo_cfop_cst;
/
