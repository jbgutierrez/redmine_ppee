namespace :ppee do
  
  desc "Publica una noticia con eventos relevantes (por proyecto) de la última semana: novedades en la wiki, estadística de commits, estadística de tareas, etc."
  task :create_news, [:repo_path, :wiki_path] => :environment do |t, args|
    # Movimientos en la WIKI
    pages = WikiContent.find(:all, :conditions => ['updated_on > ?', 1.week.ago]).map(&:page).uniq
    pages_by_project = pages.group_by{|p| p.wiki.project }.to_hash

    # Movimientos en las tareas
    opened_issues_per_project = []
    touched_issues_per_project = []
    Project.all.each do |project|
      opened_issues_per_project << [project, project.issues.count(:conditions => ['created_on > ?', 1.week.ago])]
      touched_issues_per_project << [project, project.issues.count(:conditions => ['updated_on > ?', 1.week.ago])]
    end
    
    # Estadísticas del repositorio
    repo_path = args[:repo_path]
    commits_per_project = []
    projects_tagged = []
    begin
      command = "svn list #{repo_path}"
      projects = `#{command}`.map(&:chomp).map(&:chop!)
      projects.each do |project|
        DATE_FORMAT = '%Y-%m-%d'
        start_date = 1.week.ago.strftime(DATE_FORMAT)
        today = DateTime.now.strftime(DATE_FORMAT)
        command = "svn log -q -r {#{start_date}}:{#{today}} #{repo_path}#{project}"
        commits = `#{command}`.reject{|l| l =~ /^-/}
        raise "Ups! Esta semana no hay estadísticas. Algo ha pasado con el repo!" unless $?.success?
        unless commits.empty?
          commits_per_project << [project, commits] 
        end
        command = "svn log -q -r {#{start_date}}:{#{today}} #{repo_path}#{project}/Software/tags"
        commits = `#{command}`.reject{|l| l =~ /^-/}
        projects_tagged << project unless commits.empty?
      end
    rescue => x
      puts x.message
    end

    append_separator = Proc.new do |array|
      result = ""
      result << "* Ninguno\n" if array.empty?
      result << "\n"
      result
    end

    #Maquetación de la noticia
    wiki_path = args[:wiki_path]
    text = ""
    text << "h2. Movimientos en la wiki\n\n"
    pages_by_project.each_pair do |project, pages|
      text << "h3. #{project}\n\n"
      pages.each {|p| text << "* \"#{p.title.gsub("_", " ")}\":#{wiki_path}/#{project}/#{p.title}\n" }
    end
    text << append_separator.call(pages_by_project)
  
    text << "h2. Estadísticas del repositorio\n\n"
    text << "h3. Proyectos etiquetados\n\n"
    projects_tagged.each { |p| text << "* #{p}\n" }
    text << append_separator.call(projects_tagged)
  
    text << "h3. Ranking de commits\n\n"
    commits_per_project.sort_by{|pair| pair[1].size }.reverse!.each do |pair|
      project = pair[0]
      commits = pair[1]
      text << "* #{commits.size} - #{project}\n" unless commits.empty?
    end
    text << append_separator.call(commits_per_project)
  
    text << "h2. Estadísticas de incidencias/tareas\n\n"
    text << "h3. Actualizadas\n\n"
    touched_issues_per_project.sort_by{|pair| pair[1] }.reverse!.each do |pair|
      project = pair[0]
      count = pair[1]
      text << "* #{count} - #{project}\n" unless count == 0
    end
    text << append_separator.call(touched_issues_per_project)
  
    text << "h3. Abiertas\n\n"
    opened_issues_per_project.sort_by{|pair| pair[1] }.reverse!.each do |pair|
      project = pair[0]
      count = pair[1]
      text << "* #{count} - #{project}\n" unless count == 0
    end
    text << append_separator.call(opened_issues_per_project)
    
    params = {}
    params[:project_id] = Project.find_by_name('PPEE').id
    params[:author_id] = User.find_by_login('admin')
    params[:title] = "Resumen semanal"
    params[:description] = text
    News.create(params)
  end

end
