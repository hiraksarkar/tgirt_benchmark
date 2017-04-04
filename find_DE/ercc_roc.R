#!/usr/bin/env Rscript

library(readr)
library(dplyr)
library(feather)
library(cowplot)
library(stringr)
library(tidyr)
library(purrr)

# read gene table
ercc_file <- '/stor/work/Lambowitz/ref/RNASeqConsortium/ercc/ercc_table.tsv' %>%
    read_tsv()  %>%
    tbl_df

# read all tables ====================================================
project_path <- '/stor/scratch/Lambowitz/cdw2854/bench_marking'
alignment_free_df <- project_path %>%
    str_c('/alignment_free/countFiles/sleuth_results.feather') %>%
    read_feather() %>%
    mutate(logFC = -b) %>%
    dplyr::rename(id = gene_id) %>%
    select(id,sample_base,sample_test, name,type,qval, mean_obs, logFC, pval) %>%
    gather(variable, value, -id,-name,-type,-sample_base,-sample_test) %>%
    mutate(variable = case_when(
        .$variable == 'qval' ~ 'adj.P.Val',
        .$variable == 'mean_obs' ~ 'AveExpr',
        .$variable == 'logFC' ~ 'logFC',
        .$variable == 'pval' ~ 'P.Val'
    ))  %>%
    mutate(variable = str_c(variable,'_', sample_base, sample_test)) %>%
    select(-sample_base,-sample_test) %>%
    spread(variable, value)  %>%
    select(-name,-type) %>%
    right_join(ercc_file) %>%
    select(-group,-mix1,-mix2,-fold,-log2fold,-label) %>%
    mutate(map_type = 'Kallisto') %>%
    tbl_df

genome_df <- project_path %>%
    str_c('/genome_mapping/pipeline7_counts/deseq_genome.feather') %>%
    read_feather() %>%
    tbl_df


df <- rbind(genome_df, alignment_free_df) %>%
    inner_join(ercc_file,by='id') %>%
    select(map_type, id, logFC_AB, group,fold, mix1,mix2,adj.P.Val_AB,label) %>%
    mutate(log2fold = log2(fold)) %>%
    mutate(av_exp = (mix1+mix2)/2) %>%
    mutate(adj.P.Val_AB = ifelse(is.na(adj.P.Val_AB),1,adj.P.Val_AB)) %>%
    mutate(error = logFC_AB-log2fold)  %>% 
    tbl_df

rmse_df <- df %>% 
    group_by(map_type)  %>%
    summarize(rmse = sqrt(mean(error^2)))

ercc_de_p<-ggplot()+
    geom_point(data=df, aes(x = log2(av_exp), 
                            y = logFC_AB, 
                            color = group)) +
    geom_hline(data=df %>% select(group, log2fold),
               aes(yintercept = log2fold, color = group)) +
    geom_text(data=rmse_df, x= 5, y = 2.5,
              aes(label = str_c('RMSE: ',signif(rmse,3)))) +
    facet_grid(~map_type) +
    labs(x = 'log2(average expression)', 
         y = 'log2(Fold change between AB)', 
         color = ' ')



## plotting roc curve
roc_data <- function(p_cut, de_df){
   de_df %>%
        mutate(DE = ifelse(adj.P.Val_AB<p_cut, 'DE','notDE')) %>%
        group_by(map_type,DE,label) %>%
        summarize(count = n())  %>%
        ungroup() %>%
        mutate(p = p_cut) 
}

# 23 non DE in ERCC, 69 DE
roc_df <- df %>% 
    mutate(logFC_AB = ifelse(is.na(logFC_AB),1,logFC_AB)) %>%
    map_df(seq(0,1,0.001), roc_data,.) %>%
    mutate(label = str_c(DE,'-',label)) %>%
    mutate(label = case_when(
                    .$label == 'notDE-DE' ~ 'FN',
                    .$label == 'notDE-notDE' ~ 'TN',
                    .$label == 'DE-DE' ~ 'TP',
                    .$label == 'DE-notDE' ~ 'FP'
    )) %>%
    select(-DE) %>%
    spread(label,count, fill=0)%>%
    mutate(TPR = TP/(TP+FN)) %>%
    mutate(FPR = FP/(TN+FP)) %>%
    mutate(slope = TPR/FPR) %>%
    tbl_df

label_df <-  roc_df %>% 
    group_by(map_type) %>%
    top_n(1,slope) %>%
    do(head(.,1)) %>%
    ungroup() %>%
    mutate(label = str_c('p = ',signif(p,3))) %>%
    tbl_df

roc_p <- ggplot(data=roc_df, aes(x = FPR, y = TPR, color = map_type)) +
    geom_point() +
    geom_line()+
    ggrepel::geom_label_repel(data=label_df, 
                              aes(x = FPR, y = TPR, label = label, color = map_type)) +
    labs(x = 'False positive rate', y = 'True positive rate', color = ' ') +
    theme(legend.position = c(0.75,0.25)) +
    geom_abline(slope = 1, intercept = 0)


p <- plot_grid(ercc_de_p, roc_p, ncol=1)
figurepath <- str_c(project_path, '/figures')
figurename <- str_c(figurepath, '/ercc_roc.png')
save_plot(p, file=figurename,  base_width=10, base_height=10) 
message('Saved: ', figurename)