namespace :ppee do
  
  desc "Borra los ficheros subidos en el proyecto PPEE durante la última semana"
  task :clear_stale_files => :environment do
    Project.find_by_name('PPEE').attachments.find(:all, :conditions => ['created_on < ?', 1.week.ago]).each(&:destroy)
  end

end
