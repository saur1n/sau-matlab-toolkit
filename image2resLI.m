%%  Sau MATLAB Colony Analyzer Toolkit
%
%%  image2resLI.m

%   Author: Saurin Parikh, February 2019
%   dr.saurin.parikh@gmail.com
%   
%   Analyze Images -> Upload Data
%   and then
%   JPEG data to Q-VALUES for any experiment with Linear Interpolation 
%   based Control Normalization.
%   Inputs Required:
%       sql info (username, password, database name), experiment name,
%       pos2coor tablename, pos2orf_name tablename, control name,
%       borderpos, smudgebox
% 
%   Recursive parent directory search to search all subdirectories
%   containing images.

%%  Load Paths to Files and Data
    
    load_toolkit;

%%  Initialization

%     Set preferences with setdbprefs.
    setdbprefs('DataReturnFormat', 'structure');
    setdbprefs({'NullStringRead';'NullStringWrite';'NullNumberRead';'NullNumberWrite'},...
                  {'null';'null';'NaN';'NaN'})
    
%     prompt={'Enter the name of your MySQL Username:'};
%     username = char(inputdlg(prompt,...
%         'SQL Username',1,...
%         {'user'}));
    
%     prompt={'Enter the name of your MySQL Password:'};
%     pwd = char(inputdlg(prompt,...
%         'SQL Password',1,...
%         'password'));

%     prompt={'Enter the name of your MySQL Database:'};
%     db = char(inputdlg(prompt,...
%         'SQL Database Name',1,...
%         {'database'}));

%     prompt={'Enter a name for your experiment:'};
%     name='expt_name';
%     numlines=1;
%     defaultanswer={'test'};
%     expt_name = char(inputdlg(prompt,name,numlines,defaultanswer));
    expt_name = '4C4_TR_RND';
  
%   Set Precision
%     digits(6);
    
%   Collect all subfolders and files within them from a folder
% 
    hours = []; 
    files = {};
    filedir = dir(uigetdir());
    dirFlags = [filedir.isdir] & ~strcmp({filedir.name},'.') & ~strcmp({filedir.name},'..');
    subFolders = filedir(dirFlags);
    for k = 1 : length(subFolders)
        tmpdir = strcat(subFolders(k).folder, '/',  subFolders(k).name);
        files = [files; dirfiles(tmpdir, '*.JPG')];  
        hrs = strfind(tmpdir, '/'); hrs = tmpdir(hrs(end)+1:end);
        hours = [hours, str2num(hrs(1:end-1))];
    end
    
    if isempty(hours)
        hours = -1;
    end
      
    switch questdlg('Is density 384 or higher?',...
        'Density Options',...
        'Yes','No','Yes')
        case 'Yes'
            density = str2num(questdlg('What density plates are you using?',...
                'Density Options',...
                '384','1536','6144','6144'));
            if density == 6144
                dimensions = [64 96];
            elseif density == 1536
                dimensions = [32 48];
            else
                dimensions = [16 24];
            end
        case 'No'
            density = 96;
            dimensions = [8 12];
    end
    
%     if density == 96
%         poslim = [0,1000];
%     elseif density == 384
%         poslim = [1000,10000];
%     elseif density == 1536
%         poslim = [10000,100000];
%     else %density == 6144
%         poslim = [100000,1000000];
%     end
    
%   MySQL Table Details  
    
    tablename_jpeg      = sprintf('%s_%d_JPEG',expt_name,density);
    tablename_norm      = sprintf('%s_%d_NORM',expt_name,density);
    tablename_fit       = sprintf('%s_%d_FITNESS',expt_name,density);
    tablename_fits      = sprintf('%s_%d_FITNESS_STATS',expt_name,density);
    tablename_es        = sprintf('%s_%d_FITNESS_ES',expt_name,density);
    tablename_pval      = sprintf('%s_%d_PVALUE',expt_name,density);
    tablename_res       = sprintf('%s_%d_RES',expt_name,density);
    
%   MySQL Connection and fetch initial data

    connectSQL;
    
%     prompt={'Enter the name of your P2C Table:',...
%         'Name of the "Plate" column:',...
%         'Name of the "Column" column:',...
%         'Name of the "Row" column:'};
%     name='P2C Table Info';
%     defaultanswers={'expt_pos2coor','384plate','384col','384row'};
%     p2c_info = char(inputdlg(prompt,...
%         name,1,defaultanswers));
    
    p2c_info(1,:) = '4C4_pos2coor';
    p2c_info(2,:) = 'plate       ';
    p2c_info(3,:) = 'col         ';
    p2c_info(4,:) = 'row         ';

    p2c = fetch(conn, sprintf(['select * from %s a ',...
        'where density = %d ',...
        'order by a.%s, a.%s, a.%s'],...
        p2c_info(1,:),...
        density,...
        p2c_info(2,:),...
        p2c_info(3,:),...
        p2c_info(4,:)));
    
    n_plates = fetch(conn, sprintf(['select distinct %s from %s a ',...
        'where density = %d ',...
        'order by %s asc'],...
        p2c_info(2,:),...
        p2c_info(1,:),...
        density,...
        p2c_info(2,:)));
    
%     prompt={'Enter the name of your pos2orf_name table:'};
%     tablename_p2o = char(inputdlg(prompt,...
%         'pos2orf_name Table Name',1,...
%         {'expt_pos2orf_name'}));
    
    tablename_p2o       = '4C4_TR_pos2orf_name';
    
%     prompt={'Enter the number of replicates in this study:'};
%     replicate = str2num(cell2mat(inputdlg(prompt,...
%         'Replicates',1,...
%         {'4'})));

%     if density >384
%         prompt={'Enter the name of your source table:'};
%         tablename_null = char(inputdlg(prompt,...
%             'Source Table',1,...
%             {'expt_384_SPATIAL'}));
%         source_nulls = fetch(conn, sprintf(['select a.pos from %s a ',...
%             'where a.csS is NULL ',...
%             'order by a.pos asc'],tablename_null));
%     end
    
%     prompt={'Enter the control stain orf_name:'};
%     cont.name = char(inputdlg(prompt,...
%         'Control Strain',1,...
%         {'BF_control'}));

    cont.name = 'BF_control';
%     
%     prompt={'Enter the Border Position Table Name:'};
%     tablename_bpos = char(inputdlg(prompt,...
%         'Border Positions',1,...
%         {'expt_borderpos'}));

    tablename_bpos = '4C4_borderpos';
    
%     prompt={'Enter the Smudge Box Table Name:'};
%     tablename_sbox = char(inputdlg(prompt,...
%         'Smudge Box',1,...
%         {'expt_smudgebox'}));

    tablename_sbox = '4C4_smudgebox';
    
%   Fetch Protogenes

%     proto = fetch(conn, ['select orf_name from PROTOGENES ',...
%         'where longer + selected + translated < 3']);
%     
%     close(conn);
    
%%  ANALYZE DATA
    
    if density <= 384
        image2spatial_LD(files, hours, dimensions,...
            p2c, tablename_raw, tablename_spa)
    else
%%  Load Analyzed Data

        cs = load_colony_sizes(files);
        size(cs)    % should be = (number of plates x 3 x number of time points) x density

%%  Mean the colony sizes from each of the images

        cs_mean = [];
        tmp = cs';

%         for ii = 1:3:length(files)
%             cs_mean = [cs_mean, mean(tmp(:,ii:ii+2),2)];
%         end
%         
        for ii = 1:length(files) %single picture/time point
            cs_mean = [cs_mean, tmp(:,ii)];
        end

        cs_mean = cs_mean';

%%  Putting Colony Size(pixels) and averages together

        master = [];
        tmp = [];
%         i = 1;
%         for ii = 1:3:size(cs,1)
%             tmp = [cs(ii,:); cs(ii+1,:); cs(ii+2,:);...
%                 cs_mean(i,:)];
%             master = [master, tmp];
%             i = i + 1;
%         end

        for ii = 1:size(cs,1) %single picture/time point
            tmp = [cs(ii,:); cs(ii,:); cs(ii,:);...
                cs_mean(ii,:)];
            master = [master, tmp];
        end
        master = master';

%%  Upload JPEG Data to SQL

        connectSQL;

        exec(conn, sprintf('drop table %s',tablename_jpeg));  
        exec(conn, sprintf(['create table %s (pos int not null, hours int not null,'...
            'replicate1 int default null, replicate2 int default null, ',...
            'replicate3 int default null, average double default null)'], tablename_jpeg));

        colnames_jpeg = {'pos','hours'...
            'replicate1','replicate2','replicate3',...
            'average'};

        tmpdata = [];
        for ii=1:length(hours)
            tmpdata = [tmpdata; [p2c.pos, ones(length(p2c.pos),1)*hours(ii)]];
        end

        data = [tmpdata,master];
        tic
        datainsert(conn,tablename_jpeg,colnames_jpeg,data);
        toc

%%  SPATIAL cleanup
%   Border colonies, light artefact and smudge correction

        exec(conn, sprintf(['update %s ',...
            'set replicate1 = NULL, replicate2 = NULL, ',...
            'replicate3 = NULL, average = NULL ',...
            'where pos in ',...
            '(select pos from %s)'],tablename_jpeg,tablename_bpos));
        
        exec(conn, sprintf(['update %s ',...
            'set replicate1 = NULL, replicate2 = NULL, ',...
            'replicate3 = NULL, average = NULL ',...
            'where average <= 10'],tablename_jpeg));
        
        exec(conn, sprintf(['update %s ',...
            'set replicate1 = NULL, replicate2 = NULL, ',...
            'replicate3 = NULL, average = NULL ',...
            'where pos in ',...
            '(select pos from %s)'],tablename_jpeg,tablename_sbox));
    
%%  Upload JPEG to NORM data
%   Linear Interpolation based CN

        IL = 1; % 1 = interleave

        hours = fetch(conn, sprintf(['select distinct hours from %s ',...
            'order by hours asc'], tablename_jpeg));
        hours = hours.hours;
        
        data_fit = LinearInNorm(hours,n_plates,p2c_info,cont.name,...
            tablename_p2o,tablename_jpeg,IL);

        exec(conn, sprintf('drop table %s',tablename_norm));
        exec(conn, sprintf(['create table %s ( ',...
                    'pos int(11) not NULL, ',...
                    'hours int(11) not NULL, ',...
                    'bg double default NULL, ',...
                    'average double default NULL, ',...
                    'fitness double default NULL ',...
                    ')'],tablename_norm));
        for i=1:length(hours)
            datainsert(conn, tablename_norm,...
                {'pos','hours','bg','average','fitness'},data_fit{i});
        end

        exec(conn, sprintf('drop table %s',tablename_fit)); 
        exec(conn, sprintf(['create table %s ',...
            '(select b.orf_name, a.pos, a.hours, a.bg, a.average, a.fitness ',...
            'from %s a, %s b ',...
            'where a.pos = b.pos ',...
            'order by a.pos asc)'],tablename_fit,tablename_norm,tablename_p2o));

%%  FITNESS STATS

        clear data

        exec(conn, sprintf('drop table %s', tablename_fits));
        exec(conn, sprintf(['create table %s (orf_name varchar(255) null, ',...
            'hours int not null, N int not null, cs_mean double null, ',...
            'cs_median double null, cs_std double null)'],tablename_fits));

        colnames_fits = {'orf_name','hours','N','cs_mean','cs_median','cs_std'};

        stat_data = fit_stats(tablename_fit);
        tic
        datainsert(conn,tablename_fits,colnames_fits,stat_data)
        toc

%%  EFFECT SIZE

        exec(conn, sprintf('drop table %s', tablename_es));
        exec(conn, sprintf(['create table %s (orf_name varchar(255) null, ',...
            'hours int not null, N int not null, cs_mean double null, cs_median double null, ',...
            'cs_std double null, effect_size double null)'],tablename_es));

        colnames_es = {'orf_name','hours','N',...
            'cs_mean','cs_median','cs_std',...
            'effect_size'};

        for ii = 1:length(hours)
            fit_cont{ii} = fetch(conn, sprintf(['select * from %s ',...
                'where hours = %d and orf_name = ''%s'''],...
                tablename_fits,hours(ii),cont.name));
            fit_orf{ii} = fetch(conn, sprintf(['select * from %s ',...
                'where hours = %d and orf_name != ''%s'' ',...
                'order by orf_name asc'],...
                tablename_fits,hours(ii),cont.name));

            for i = 1:length(fit_orf{ii}.orf_name)
                fit_orf{ii}.effect_size(i,:) = fit_orf{ii}.cs_mean(i)/fit_cont{ii}.cs_mean;
            end
            tic
%             sqlwrite(conn,tablename_es,fit_orf{ii});
            datainsert(conn,tablename_es,colnames_es,fit_orf{ii})
            toc
        end
  
%%  FITNESS STATS to EMPIRICAL P VALUES

        exec(conn, sprintf('drop table %s',tablename_pval));
        exec(conn, sprintf(['create table %s (orf_name varchar(255) null,'...
            'hours int not null, p double null, stat double null)'],tablename_pval));
        colnames_pval = {'orf_name','hours','p','stat'};
        
        contpos = fetch(conn, sprintf(['select pos from %s ',...
            'where orf_name = ''%s'' and pos < 10000 ',...
            'and pos not in ',...
            '(select pos from %s)'],...
            tablename_p2o,cont.name,tablename_bpos));
        contpos = contpos.pos + [110000,120000,130000,140000,...
            210000,220000,230000,240000];

        for iii = 1:length(hours)
            contfit = [];
            for ii = 1:length(contpos)
                temp = fetch(conn, sprintf(['select fitness from %s ',...
                    'where hours = %d and pos in (%s) ',...
                    'and fitness is not null'],tablename_fit,hours(iii),...
                    sprintf('%d,%d,%d,%d,%d,%d,%d,%d',contpos(ii,:))));
                
                if nansum(temp.fitness) > 0
                    outlier = isoutlier(temp.fitness);
                    temp.fitness(outlier) = NaN;
                    contfit = [contfit, nanmean(temp.fitness)];
                end
            end
            contmean = nanmean(contfit);
            contstd = nanstd(contfit);

            orffit = fetch(conn, sprintf(['select orf_name, cs_median, ',...
                'cs_mean, cs_std from %s ',...
                'where hours = %d and orf_name != ''%s'' ',...
                'order by orf_name asc'],tablename_fits,hours(iii),cont.name));

            m = contfit';
            tt = length(m);
            pvals = [];
            stat = [];
            for i = 1:length(orffit.orf_name)
                if sum(m<orffit.cs_mean(i)) < tt/2
                    if m<orffit.cs_mean(i) == 0
                        pvals = [pvals; 1/tt];
                        stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                    else
                        pvals = [pvals; ((sum(m<=orffit.cs_mean(i)))/tt)*2];
                        stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                    end
                else
                    pvals = [pvals; ((sum(m>=orffit.cs_mean(i)))/tt)*2];
                    stat = [stat; (orffit.cs_mean(i) - contmean)/contstd];
                end
            end

            pdata{iii}.orf_name = orffit.orf_name;
            pdata{iii}.hours = ones(length(pdata{iii}.orf_name),1)*hours(iii);
            pdata{iii}.p = num2cell(pvals);
            pdata{iii}.p(cellfun(@isnan,pdata{iii}.p)) = {[]};
            pdata{iii}.stat = num2cell(stat);
            pdata{iii}.stat(cellfun(@isnan,pdata{iii}.stat)) = {[]};
            
%             datainsert(conn,tablename_pval,colnames_pval,pdata{iii})
            sqlwrite(conn,tablename_pval,struct2table(pdata{iii}));
        end
        
%%  SAVING DATA

        rep = 16;
        
        for i = 1:length(hours)
            cont_hrs = hours(i);
            
            temp_stat_p = fetch(conn, sprintf(['select a.*, b.p ',...
                'from %s a, %s b ',...
                'where a.orf_name = b.orf_name ',...
                'and a.orf_name != ''BFC100'' ',...
                'and a.hours = b.hours ',...
                'and a.hours = %0.2f ',...
                'order by a.hours, a.orf_name'], tablename_fits, tablename_pval, cont_hrs));
            writetable(temp_stat_p,...
                sprintf('%s_%d_%d_1_STATS_P.csv',expt_name,rep,i),...
                'Delimiter',',',...
                'QuoteStrings',true)

            temp_fitness = fetch(conn, sprintf(['select a.hours, a.pos, b.plate, b.col, b.row, ',...
                'a.orf_name, a.bg, a.average, a.fitness ',...
                'from %s a, %s b ',...
                'where a.pos = b.pos and a.hours = %0.2f ',...
                'order by a.hours, b.%s, b.%s, b.%s'],...
                tablename_fit,p2c_info{1},...
                            cont_hrs,...
                            p2c_info{2},...
                            p2c_info{4},...
                            p2c_info{3}));        
             writetable(temp_fitness,...
                sprintf('%s_%d_%d_1_FITNESS.csv',expt_name,rep,i),...
                'Delimiter',',',...
                'QuoteStrings',true)
        end
        
    end
    